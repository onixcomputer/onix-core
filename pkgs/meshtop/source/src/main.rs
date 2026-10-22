mod collector;
mod identity;
mod model;
mod transport;
mod ui;

use std::collections::HashSet;
use std::fs;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::time::Duration;

use anyhow::{Context, Result, bail};
use clap::{Parser, Subcommand};
use iroh::{Endpoint, EndpointAddr, EndpointId, RelayMode, SecretKey, endpoint::presets};
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc;
use tokio::time::{sleep, timeout};

const DIAL_TIMEOUT: Duration = Duration::from_secs(8);
const SAMPLE_TIMEOUT: Duration = Duration::from_secs(4);
const RETRY_DELAY: Duration = Duration::from_secs(2);
const SAMPLE_INTERVAL: Duration = Duration::from_secs(1);

#[derive(Parser)]
#[command(version, about = "Read-only multi-host system monitor over Iroh")]
struct Args {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Create or display the stable viewer identity to authorize on agents.
    Id {
        #[arg(long)]
        key: Option<PathBuf>,
    },
    /// Serve snapshots to exactly one pinned viewer identity.
    Agent {
        #[arg(long, help = "Endpoint ID printed by `meshtop id` on the viewer")]
        viewer: EndpointId,
        #[arg(long)]
        key: Option<PathBuf>,
        #[arg(long)]
        name: Option<String>,
        #[arg(
            long,
            help = "Only use direct IP routes; no DNS discovery or public relays"
        )]
        direct_only: bool,
        #[arg(long, help = "Optional local IP:port, e.g. 127.0.0.1:0")]
        bind: Option<SocketAddr>,
    },
    /// Show all pinned agents in an interactive terminal (or JSON with --once).
    Watch {
        #[arg(long = "host", value_name = "NAME=ENDPOINT_ID[@IP:PORT]")]
        hosts: Vec<String>,
        #[arg(
            long,
            value_name = "FILE",
            help = "TOML file with [[hosts]] name, id, optional address"
        )]
        hosts_file: Option<PathBuf>,
        #[arg(long)]
        key: Option<PathBuf>,
        #[arg(
            long,
            help = "Only use direct IP routes; requires explicit host addresses"
        )]
        direct_only: bool,
        #[arg(
            long,
            help = "Fetch one sample per host and print JSON; do not enter the TUI"
        )]
        once: bool,
    },
}

#[derive(Clone)]
struct Host {
    name: String,
    id: EndpointId,
    address: EndpointAddr,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct HostFile {
    hosts: Vec<HostEntry>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct HostEntry {
    name: String,
    id: String,
    address: Option<SocketAddr>,
}

#[derive(Serialize)]
struct OnceResult {
    name: String,
    id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    snapshot: Option<model::Snapshot>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[tokio::main(flavor = "multi_thread")]
async fn main() -> Result<()> {
    match Args::parse().command {
        Command::Id { key } => {
            let key = key
                .map(Ok)
                .unwrap_or_else(|| identity::default_path(false))?;
            println!("{}", identity::load_or_create(&key)?.public());
        }
        Command::Agent {
            viewer,
            key,
            name,
            direct_only,
            bind,
        } => {
            let key = key
                .map(Ok)
                .unwrap_or_else(|| identity::default_path(true))?;
            let secret = identity::load_or_create(&key)?;
            let endpoint = bind_endpoint(secret, direct_only, true, bind).await?;
            println!("agent id: {}", endpoint.id());
            println!("authorized viewer: {viewer}");
            for addr in endpoint.addr().ip_addrs() {
                println!("direct address: {addr}");
            }
            println!("Ctrl-C to stop");
            let result = tokio::select! {
                result = transport::serve(endpoint.clone(), viewer, name) => result,
                signal = tokio::signal::ctrl_c() => signal.context("waiting for Ctrl-C"),
            };
            endpoint.close().await;
            result?;
        }
        Command::Watch {
            hosts,
            hosts_file,
            key,
            direct_only,
            once,
        } => {
            let peers = load_hosts(hosts_file.as_deref(), &hosts)?;
            if direct_only && peers.iter().any(|peer| peer.address.is_empty()) {
                bail!("--direct-only requires an IP:port for every host");
            }
            let key = key
                .map(Ok)
                .unwrap_or_else(|| identity::default_path(false))?;
            let secret = identity::load_or_create(&key)?;
            let endpoint = bind_endpoint(secret, direct_only, false, None).await?;
            let result = if once {
                show_once(endpoint.clone(), peers).await
            } else {
                let (updates, rx) = mpsc::channel(64);
                let labels = peers.iter().map(|peer| peer.name.clone()).collect();
                for (index, peer) in peers.into_iter().enumerate() {
                    tokio::spawn(watch_host(endpoint.clone(), peer, index, updates.clone()));
                }
                drop(updates);
                ui::run(labels, rx)
            };
            endpoint.close().await;
            result?;
        }
    }
    Ok(())
}

async fn bind_endpoint(
    key: SecretKey,
    direct_only: bool,
    server: bool,
    bind: Option<SocketAddr>,
) -> Result<Endpoint> {
    let mut builder = if direct_only {
        Endpoint::builder(presets::Minimal).relay_mode(RelayMode::Disabled)
    } else {
        Endpoint::builder(presets::N0)
    }
    .secret_key(key);
    if server {
        builder = builder.alpns(vec![transport::ALPN.to_vec()]);
    }
    if let Some(addr) = bind {
        // Specifying an interface must not leave the builder's default wildcard sockets open.
        builder = builder
            .clear_ip_transports()
            .bind_addr(addr)
            .context("invalid bind address")?;
    }
    builder.bind().await.context("binding Iroh endpoint")
}

async fn fetch(endpoint: &Endpoint, peer: &Host) -> Result<model::Snapshot> {
    let connection = timeout(
        DIAL_TIMEOUT,
        endpoint.connect(peer.address.clone(), transport::ALPN),
    )
    .await
    .context("dial timed out")?
    .context("dial failed")?;
    timeout(SAMPLE_TIMEOUT, transport::poll(&connection))
        .await
        .context("sample timed out")?
}

async fn watch_host(
    endpoint: Endpoint,
    peer: Host,
    index: usize,
    updates: mpsc::Sender<ui::Update>,
) {
    loop {
        let connection = timeout(
            DIAL_TIMEOUT,
            endpoint.connect(peer.address.clone(), transport::ALPN),
        )
        .await;
        match connection {
            Ok(Ok(connection)) => loop {
                let result = timeout(SAMPLE_TIMEOUT, transport::poll(&connection))
                    .await
                    .map_err(|_| anyhow::anyhow!("sample timed out"))
                    .and_then(std::convert::identity)
                    .map_err(|error| error.to_string());
                let disconnected = result.is_err();
                if updates
                    .send(ui::Update {
                        host_index: index,
                        result,
                    })
                    .await
                    .is_err()
                {
                    return;
                }
                if disconnected {
                    break;
                }
                sleep(SAMPLE_INTERVAL).await;
            },
            Ok(Err(error)) => {
                if updates
                    .send(ui::Update {
                        host_index: index,
                        result: Err(format!("dial failed: {error}")),
                    })
                    .await
                    .is_err()
                {
                    return;
                }
            }
            Err(_) => {
                if updates
                    .send(ui::Update {
                        host_index: index,
                        result: Err("dial timed out".into()),
                    })
                    .await
                    .is_err()
                {
                    return;
                }
            }
        }
        sleep(RETRY_DELAY).await;
    }
}

async fn show_once(endpoint: Endpoint, peers: Vec<Host>) -> Result<()> {
    let count = peers.len();
    let mut jobs = tokio::task::JoinSet::new();
    for (index, peer) in peers.into_iter().enumerate() {
        let endpoint = endpoint.clone();
        jobs.spawn(async move {
            let (snapshot, error) = match fetch(&endpoint, &peer).await {
                Ok(snapshot) => (Some(snapshot), None),
                Err(error) => (None, Some(error.to_string())),
            };
            (
                index,
                OnceResult {
                    name: peer.name,
                    id: peer.id.to_string(),
                    snapshot,
                    error,
                },
            )
        });
    }
    let mut rows: Vec<Option<OnceResult>> = (0..count).map(|_| None).collect();
    while let Some(result) = jobs.join_next().await {
        let (index, row) = result.context("host fetch task failed")?;
        rows[index] = Some(row);
    }
    let rows: Vec<_> = rows
        .into_iter()
        .map(|row| row.expect("all host jobs returned"))
        .collect();
    println!("{}", serde_json::to_string_pretty(&rows)?);
    if rows.iter().any(|row| row.error.is_some()) {
        bail!("one or more hosts could not be sampled");
    }
    Ok(())
}

fn load_hosts(path: Option<&Path>, entries: &[String]) -> Result<Vec<Host>> {
    let mut hosts = Vec::new();
    if let Some(path) = path {
        let metadata = fs::metadata(path).with_context(|| format!("reading {}", path.display()))?;
        if metadata.len() > 32 * 1024 {
            bail!("hosts file exceeds 32 KiB");
        }
        let file: HostFile = toml::from_str(&fs::read_to_string(path)?)
            .with_context(|| format!("parsing hosts file {}", path.display()))?;
        for host in file.hosts {
            hosts.push(parse_host(&host.name, &host.id, host.address)?);
        }
    }
    for entry in entries {
        let (name, target) = entry
            .split_once('=')
            .context("--host must be NAME=ENDPOINT_ID[@IP:PORT]")?;
        let (id, address) = match target.rsplit_once('@') {
            Some((id, addr)) => (id, Some(addr.parse().context("invalid host IP:port")?)),
            None => (target, None),
        };
        hosts.push(parse_host(name, id, address)?);
    }
    if hosts.is_empty() || hosts.len() > 64 {
        bail!("provide between 1 and 64 hosts with --host or --hosts-file");
    }
    let mut names = HashSet::new();
    let mut ids = HashSet::new();
    for host in &hosts {
        if !names.insert(&host.name) || !ids.insert(host.id) {
            bail!("host names and endpoint IDs must be unique");
        }
    }
    Ok(hosts)
}

fn parse_host(name: &str, id: &str, addr: Option<SocketAddr>) -> Result<Host> {
    if name.is_empty() || name.len() > 64 || name.chars().any(char::is_control) {
        bail!("host name must be 1..64 bytes without control characters");
    }
    let id: EndpointId = id.parse().context("invalid Iroh endpoint ID")?;
    let mut address = EndpointAddr::new(id);
    if let Some(addr) = addr {
        address = address.with_ip_addr(addr);
    }
    Ok(Host {
        name: name.to_owned(),
        id,
        address,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_duplicate_and_malformed_hosts() {
        let id = SecretKey::generate().public();
        let good = format!("home={id}@127.0.0.1:1234");
        assert_eq!(
            load_hosts(None, std::slice::from_ref(&good)).unwrap()[0]
                .address
                .ip_addrs()
                .count(),
            1
        );
        assert!(load_hosts(None, &[good.clone(), good]).is_err());
        assert!(load_hosts(None, &[format!("bad\nname={id}")]).is_err());
        assert!(load_hosts(None, &[format!("host={id}@not-an-ip")]).is_err());
    }

    #[tokio::test]
    async fn explicit_ipv4_bind_does_not_expose_an_ipv6_wildcard() {
        let endpoint = bind_endpoint(
            SecretKey::generate(),
            true,
            true,
            Some("127.0.0.1:0".parse().unwrap()),
        )
        .await
        .unwrap();
        let addr = endpoint.addr();
        let direct: Vec<_> = addr.ip_addrs().collect();
        assert!(!direct.is_empty());
        assert!(
            direct
                .iter()
                .all(|addr| addr.ip().is_ipv4() && addr.ip().is_loopback())
        );
        endpoint.close().await;
    }
}
