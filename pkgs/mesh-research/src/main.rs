use std::{
    net::SocketAddr,
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
    time::Duration,
};

use anyhow::{Context, Result, bail, ensure};
use mesh_llm_plugin::{
    Plugin, PluginContext, PluginError, PluginResult, PluginRuntime, async_trait, bind_side_stream,
    plugin_server_info, proto,
};
use rmcp::model::ServerInfo;
use serde::Deserialize;
use serde_json::{Value, json};
use tokio::{io::copy_bidirectional, net::TcpStream, time::timeout};

const PLUGIN: &str = "research";
const CHANNEL: &str = "research-http-v1";
const DEADLINE: Duration = Duration::from_secs(90);
const MAX_RESPONSE: usize = 512 * 1024;

#[derive(Deserialize)]
#[serde(tag = "mode", rename_all = "lowercase", deny_unknown_fields)]
enum Mode {
    Provider {
        arxiv: Option<SocketAddr>,
        laya: Option<SocketAddr>,
    },
    Forwarder {
        target_peer: String,
    },
}

#[derive(Clone)]
struct Research {
    mode: Arc<Mode>,
    manifest: Arc<proto::PluginManifest>,
    client: reqwest::Client,
    next_stream: Arc<AtomicU64>,
}

fn route(path: &str) -> PluginResult<&'static str> {
    match path {
        "/search" => Ok("/search"),
        "/paper" => Ok("/paper"),
        "/predict" => Ok("/predict"),
        _ => Err(PluginError::invalid_params("Unknown research route")),
    }
}

fn stream_route(request: &proto::OpenStreamRequest) -> PluginResult<&'static str> {
    if request.mode != proto::StreamMode::Http1 as i32
        || request.purpose != proto::StreamPurpose::Generic as i32
        || !request.bidirectional
    {
        return Err(PluginError::invalid_params(
            "Research streams require bidirectional HTTP/1",
        ));
    }
    let metadata: Value = serde_json::from_str(request.metadata_json.as_deref().unwrap_or("{}"))
        .map_err(|error| PluginError::invalid_params(error.to_string()))?;
    if metadata["method"] != "POST" {
        return Err(PluginError::invalid_params("Research streams require POST"));
    }
    route(metadata["path"].as_str().unwrap_or(""))
}

impl Research {
    fn address(&self, path: &str) -> Result<SocketAddr> {
        match self.mode.as_ref() {
            Mode::Provider { arxiv, laya } => (if path == "/predict" { *laya } else { *arxiv })
                .context("Requested research backend is not configured on this peer"),
            Mode::Forwarder { .. } => bail!("A forwarder has no direct backend address"),
        }
    }

    async fn peer_stream(
        &self,
        request: proto::OpenStreamRequest,
        context: &mut PluginContext<'_>,
    ) -> Result<proto::OpenMeshStreamResponse> {
        let Mode::Forwarder { target_peer } = self.mode.as_ref() else {
            bail!("Only a forwarder opens an outbound research peer stream");
        };
        let response = timeout(
            Duration::from_secs(10),
            context.open_mesh_stream(proto::OpenMeshStreamRequest {
                stream_id: request.stream_id,
                target_peer_id: target_peer.clone(),
                plugin_id: PLUGIN.into(),
                channel: CHANNEL.into(),
                purpose: request.purpose,
                mode: request.mode,
                bidirectional: request.bidirectional,
                content_type: request.content_type,
                correlation_id: request.correlation_id,
                metadata_json: request.metadata_json,
                expected_bytes: request.expected_bytes,
                idle_timeout_ms: Some(DEADLINE.as_millis() as u64),
            }),
        )
        .await
        .context("Mesh stream setup timed out")??;
        ensure!(
            response.accepted,
            "Mesh rejected the research stream: {}",
            response.message.as_deref().unwrap_or("unknown reason")
        );
        Ok(response)
    }

    async fn invoke(
        &self,
        path: &str,
        input: Value,
        context: &mut PluginContext<'_>,
    ) -> Result<proto::InvokeServiceResponse> {
        let (client, url) = match self.mode.as_ref() {
            Mode::Provider { .. } => (
                self.client.clone(),
                format!("http://{}{path}", self.address(path)?),
            ),
            Mode::Forwarder { .. } => {
                let stream_id = format!(
                    "tool-{}-{}",
                    std::process::id(),
                    self.next_stream.fetch_add(1, Ordering::Relaxed)
                );
                let response = self
                    .peer_stream(
                        proto::OpenStreamRequest {
                            stream_id,
                            purpose: proto::StreamPurpose::Generic as i32,
                            mode: proto::StreamMode::Http1 as i32,
                            bidirectional: true,
                            content_type: Some("application/http".into()),
                            metadata_json: Some(json!({"method":"POST", "path":path}).to_string()),
                            ..Default::default()
                        },
                        context,
                    )
                    .await?;
                ensure!(
                    response.transport_kind == proto::StreamTransportKind::StreamUnixSocket as i32,
                    "Mesh returned an unsupported local stream transport"
                );
                let socket = response
                    .endpoint
                    .context("Mesh returned no stream endpoint")?;
                let client = http_client().unix_socket(socket).build()?;
                (client, format!("http://research.local{path}"))
            }
        };
        let mut response = client
            .post(url)
            .json(&input)
            .send()
            .await
            .context("Research HTTP request failed")?;
        let is_error = !response.status().is_success();
        let size = response.content_length().unwrap_or(0);
        ensure!(
            size <= MAX_RESPONSE as u64,
            "Research response exceeds 512 KiB"
        );
        let mut bytes = Vec::with_capacity(size as usize);
        while let Some(chunk) = response.chunk().await? {
            ensure!(
                bytes.len() + chunk.len() <= MAX_RESPONSE,
                "Research response exceeds 512 KiB"
            );
            bytes.extend_from_slice(&chunk);
        }
        serde_json::from_slice::<serde::de::IgnoredAny>(&bytes)
            .context("Research backend returned invalid JSON")?;
        Ok(proto::InvokeServiceResponse {
            output_json: String::from_utf8(bytes)?,
            is_error,
        })
    }
}

fn http_client() -> reqwest::ClientBuilder {
    reqwest::Client::builder()
        .no_proxy()
        .redirect(reqwest::redirect::Policy::none())
        .timeout(DEADLINE)
        .pool_max_idle_per_host(0)
}

// r[impl onix.research-tools.mesh]
#[async_trait]
impl Plugin for Research {
    fn plugin_id(&self) -> &str {
        PLUGIN
    }
    fn plugin_version(&self) -> String {
        env!("CARGO_PKG_VERSION").into()
    }
    fn server_info(&self) -> ServerInfo {
        plugin_server_info(
            PLUGIN,
            env!("CARGO_PKG_VERSION"),
            "Onix research services",
            "Pinned arXiv corpus and Laya typed decisions over the private mesh",
            None::<String>,
        )
    }
    fn manifest(&self) -> Option<proto::PluginManifest> {
        Some(self.manifest.as_ref().clone())
    }

    async fn on_mesh_event(
        &mut self,
        event: proto::MeshEvent,
        _context: &mut PluginContext<'_>,
    ) -> Result<()> {
        if matches!(self.mode.as_ref(), Mode::Provider { .. }) && !event.local_peer_id.is_empty() {
            eprintln!("research provider peer: {}", event.local_peer_id);
        }
        Ok(())
    }

    async fn invoke_service(
        &mut self,
        request: proto::InvokeServiceRequest,
        context: &mut PluginContext<'_>,
    ) -> PluginResult<Option<proto::InvokeServiceResponse>> {
        if request.kind != proto::ServiceKind::Operation as i32 {
            return Ok(None);
        }
        if request.input_json.len() > 32768 {
            return Err(PluginError::invalid_params(
                "Research request exceeds 32 KiB",
            ));
        }
        let mut input: serde_json::Map<String, Value> =
            serde_json::from_str(&request.input_json)
                .map_err(|error| PluginError::invalid_params(error.to_string()))?;
        let path = match request.service_name.as_str() {
            "arxiv_corpus" => match input.get("action").and_then(Value::as_str) {
                Some("search") => "/search",
                Some("read") => "/paper",
                _ => {
                    return Err(PluginError::invalid_params(
                        "arxiv_corpus action must be search or read",
                    ));
                }
            },
            "laya_decide" => "/predict",
            _ => return Ok(None),
        };
        if request.service_name == "arxiv_corpus" {
            input.retain(|key, _| match path {
                "/search" => matches!(key.as_str(), "query" | "limit" | "category"),
                _ => matches!(key.as_str(), "paper_id" | "offset" | "length"),
            });
        }
        let response = timeout(DEADLINE, self.invoke(path, Value::Object(input), context))
            .await
            .map_err(|_| PluginError::internal("Research request exceeded 90 seconds"))??;
        Ok(Some(response))
    }

    async fn open_stream(
        &mut self,
        request: proto::OpenStreamRequest,
        context: &mut PluginContext<'_>,
    ) -> PluginResult<Option<proto::OpenStreamResponse>> {
        let path = stream_route(&request)?;
        if matches!(self.mode.as_ref(), Mode::Forwarder { .. }) {
            let response = self.peer_stream(request, context).await?;
            return Ok(Some(proto::OpenStreamResponse {
                stream_id: response.stream_id,
                accepted: response.accepted,
                transport_kind: response.transport_kind,
                endpoint: response.endpoint,
                token: response.token,
                expires_at_unix_ms: response.expires_at_unix_ms,
                message: response.message,
            }));
        }
        let address = self.address(path)?;
        let listener = bind_side_stream(PLUGIN, &request.stream_id).await?;
        let response = listener.open_stream_response(&request);
        let endpoint = listener.endpoint();
        tokio::spawn(async move {
            let result = timeout(DEADLINE, async {
                let mesh_llm_plugin::LocalStream::Unix(mut stream) = listener.accept().await?;
                let mut backend = TcpStream::connect(address).await?;
                copy_bidirectional(&mut stream, &mut backend).await?;
                Ok::<_, anyhow::Error>(())
            })
            .await;
            // The SDK removes an accepted socket; also remove one abandoned before accept.
            if let Err(error) = tokio::fs::remove_file(&endpoint).await {
                if error.kind() != std::io::ErrorKind::NotFound {
                    eprintln!("research socket cleanup failed: {error}");
                }
            }
            match result {
                Ok(Ok(())) => {}
                Ok(Err(error)) => eprintln!("research peer bridge failed: {error:#}"),
                Err(_) => eprintln!("research peer bridge exceeded 90 seconds"),
            }
        });
        Ok(Some(response))
    }
}

fn manifest(mode: &Mode) -> Result<proto::PluginManifest> {
    let (arxiv_enabled, laya_enabled) = match mode {
        Mode::Provider { arxiv, laya } => (arxiv.is_some(), laya.is_some()),
        Mode::Forwarder { .. } => (true, true),
    };
    let definitions: serde_json::Map<String, Value> =
        serde_json::from_str(include_str!("../operations.json"))?;
    let operations = definitions
        .into_iter()
        .filter(|(name, _)| match name.as_str() {
            "arxiv_corpus" => arxiv_enabled,
            "laya_decide" => laya_enabled,
            _ => false,
        })
        .map(|(name, definition)| proto::OperationManifest {
            name,
            title: definition["title"].as_str().map(str::to_owned),
            description: definition["description"]
                .as_str()
                .unwrap_or_default()
                .into(),
            input_schema_json: definition["inputSchema"].to_string(),
            output_schema_json: None,
        })
        .collect();
    let http_bindings = ["/search", "/paper", "/predict"]
        .into_iter()
        .filter(|path| {
            if *path == "/predict" {
                laya_enabled
            } else {
                arxiv_enabled
            }
        })
        .map(|path| proto::HttpBindingManifest {
            binding_id: path.trim_start_matches('/').into(),
            method: proto::HttpMethod::Post as i32,
            path: path.into(),
            request_body_mode: proto::HttpBodyMode::Streamed as i32,
            response_body_mode: proto::HttpBodyMode::Streamed as i32,
            ..Default::default()
        })
        .collect();
    Ok(proto::PluginManifest {
        operations,
        http_bindings,
        mesh_channels: vec![proto::MeshChannelManifest {
            name: CHANNEL.into(),
        }],
        mesh_event_subscriptions: vec![proto::MeshEventSubscriptionManifest {
            kind: proto::mesh_event::Kind::LocalAccepting as i32,
        }],
        capabilities: vec!["research:read-only".into()],
        ..Default::default()
    })
}

#[tokio::main(worker_threads = 2)]
async fn main() -> Result<()> {
    let mut args = std::env::args_os().skip(1);
    let path = args
        .next()
        .context("Usage: onix-mesh-research CONFIG.json")?;
    ensure!(
        args.next().is_none(),
        "Usage: onix-mesh-research CONFIG.json"
    );
    let mode: Mode = serde_json::from_slice(&std::fs::read(path)?)?;
    match &mode {
        Mode::Provider { arxiv, laya } => {
            ensure!(
                arxiv.is_some() || laya.is_some(),
                "A research provider requires at least one backend"
            );
            for address in [arxiv, laya].into_iter().flatten() {
                let ip = address.ip();
                let private = ip.is_loopback()
                    || matches!(ip, std::net::IpAddr::V4(ip) if ip.octets()[0] == 100 && (64..=127).contains(&ip.octets()[1]));
                ensure!(
                    private && address.port() != 0,
                    "Research backends must use loopback or Tailscale addresses"
                );
            }
        }
        Mode::Forwarder { target_peer } => ensure!(
            target_peer.len() == 64
                && target_peer
                    .bytes()
                    .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte)),
            "target_peer must be a full lowercase Mesh peer ID"
        ),
    }
    let manifest = Arc::new(manifest(&mode)?);
    PluginRuntime::run(Research {
        mode: Arc::new(mode),
        manifest,
        client: http_client().build()?,
        next_stream: Arc::new(AtomicU64::new(1)),
    })
    .await
}
