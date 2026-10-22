use std::time::Duration;

use anyhow::{Context, Result, ensure};
use iroh::{Endpoint, EndpointId, endpoint::Connection};
use tokio::time::timeout;

use crate::{collector::Collector, model::Snapshot};

pub const ALPN: &[u8] = b"meshtop/snapshot/1";
const MAX_SNAPSHOT_BYTES: usize = 64 * 1024 - 4; // Include the four-byte header in the 64 KiB wire limit.
const REQUEST: u8 = 1;
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(5);
const STREAM_TIMEOUT: Duration = Duration::from_secs(3);

/// Serializes all sampling and streams; no work is performed for unauthenticated peers.
/// The endpoint is owned here and is gracefully closed when its accept loop terminates.
pub async fn serve(
    endpoint: Endpoint,
    allowed: EndpointId,
    host_name: Option<String>,
) -> Result<()> {
    let result = serve_inner(&endpoint, allowed, host_name).await;
    endpoint.close().await;
    result
}

async fn serve_inner(
    endpoint: &Endpoint,
    allowed: EndpointId,
    host_name: Option<String>,
) -> Result<()> {
    let mut collector = Collector::new(host_name)?;
    // A second CPU refresh needs at least one sysinfo sampling interval;
    // otherwise the first (and --once's only) per-core sample is zero.
    tokio::time::sleep(sysinfo::MINIMUM_CPU_UPDATE_INTERVAL).await;
    let mut active: Option<Connection> = None;
    loop {
        if let Some(connection) = &active {
            tokio::select! {
                incoming = endpoint.accept() => match incoming {
                    Some(incoming) => incoming.refuse(), // At most one live connection, even from the permitted ID.
                    None => break,
                },
                stream = connection.accept_bi() => match stream {
                    Ok((mut send, mut recv)) => {
                        // A stalled or oversized request cannot monopolize the sampler.
                        let request = timeout(STREAM_TIMEOUT, recv.read_to_end(1)).await;
                        if matches!(&request, Ok(Ok(bytes)) if bytes.as_slice() == [REQUEST]) {
                            let snapshot = collector.sample();
                            if let Ok(frame) = encode_snapshot(&snapshot) {
                                let _ = timeout(STREAM_TIMEOUT, async {
                                    send.write_all(&frame).await?;
                                    send.finish()?;
                                    Ok::<_, anyhow::Error>(())
                                }).await;
                            }
                        }
                        // Dropping either half aborts malformed, timed-out, or disconnected streams.
                    }
                    Err(_) => {
                        active = None;
                    }
                },
            }
        } else {
            let Some(incoming) = endpoint.accept().await else {
                break;
            };
            // The ID comes from Iroh's authenticated handshake, not a client-supplied field.
            if let Ok(accepting) = incoming.accept()
                && let Ok(Ok(connection)) = timeout(HANDSHAKE_TIMEOUT, accepting).await
            {
                if connection.remote_id() == allowed {
                    connection.set_max_concurrent_bi_streams(1u32.into());
                    active = Some(connection);
                } else {
                    connection.close(1u32.into(), b"unauthorized");
                }
            }
        }
    }
    Ok(())
}

fn encode_snapshot(snapshot: &Snapshot) -> Result<Vec<u8>> {
    let body = serde_json::to_vec(snapshot).context("serializing snapshot")?;
    ensure!(body.len() <= MAX_SNAPSHOT_BYTES, "snapshot exceeds 64 KiB");
    let mut frame = Vec::with_capacity(4 + body.len());
    frame.extend_from_slice(&(body.len() as u32).to_be_bytes());
    frame.extend_from_slice(&body);
    Ok(frame)
}

fn decode_snapshot(frame: &[u8]) -> Result<Snapshot> {
    ensure!(frame.len() >= 4, "truncated snapshot header");
    let len = u32::from_be_bytes(frame[..4].try_into()?) as usize;
    ensure!(len <= MAX_SNAPSHOT_BYTES, "snapshot exceeds 64 KiB");
    ensure!(frame.len() == len + 4, "invalid snapshot length");
    serde_json::from_slice(&frame[4..]).context("decoding snapshot")
}

/// One read-only request per bidirectional stream. All input and output is size- and time-bounded.
pub async fn poll(connection: &Connection) -> Result<Snapshot> {
    timeout(STREAM_TIMEOUT, async {
        let (mut send, mut recv) = connection
            .open_bi()
            .await
            .context("opening snapshot stream")?;
        send.write_all(&[REQUEST])
            .await
            .context("sending snapshot request")?;
        send.finish().context("finishing snapshot request")?;
        let frame = recv
            .read_to_end(MAX_SNAPSHOT_BYTES + 4)
            .await
            .context("reading snapshot")?;
        decode_snapshot(&frame)
    })
    .await
    .context("snapshot request timed out")?
}

#[cfg(test)]
mod tests {
    use super::*;
    use iroh::{RelayMode, endpoint::presets};

    #[test]
    fn rejects_oversized_and_inconsistent_frames() {
        let mut frame = (MAX_SNAPSHOT_BYTES as u32 + 1).to_be_bytes().to_vec();
        assert!(decode_snapshot(&frame).is_err());
        frame = 5u32.to_be_bytes().to_vec();
        frame.push(b'x');
        assert!(decode_snapshot(&frame).is_err());
        let mut snapshot = Collector::new(Some("frame".into())).unwrap().sample();
        snapshot.host = "x".repeat(MAX_SNAPSHOT_BYTES + 1);
        assert!(encode_snapshot(&snapshot).is_err());
    }

    async fn endpoint(server: bool) -> Endpoint {
        let builder = Endpoint::builder(presets::Minimal).relay_mode(RelayMode::Disabled);
        let builder = if server {
            builder.alpns(vec![ALPN.to_vec()])
        } else {
            builder
        };
        builder.bind().await.unwrap()
    }

    #[tokio::test]
    async fn only_configured_endpoint_can_read_real_sample() {
        let server = endpoint(true).await;
        let authorized = endpoint(false).await;
        let intruder = endpoint(false).await;
        let addr = server.addr();
        let serve_task = tokio::spawn(serve(
            server.clone(),
            authorized.id(),
            Some("fixture".into()),
        ));

        if let Ok(wrong) = timeout(
            Duration::from_secs(10),
            intruder.connect(addr.clone(), ALPN),
        )
        .await
        .unwrap()
        {
            assert!(
                timeout(Duration::from_secs(10), poll(&wrong))
                    .await
                    .unwrap()
                    .is_err()
            );
            wrong.close(0u32.into(), b"done");
        }

        let right = timeout(Duration::from_secs(10), authorized.connect(addr, ALPN))
            .await
            .unwrap()
            .unwrap();
        let snapshot = timeout(Duration::from_secs(10), poll(&right))
            .await
            .unwrap()
            .unwrap();
        assert_eq!(snapshot.host, "fixture");
        assert!(snapshot.memory_used <= snapshot.memory_total);
        right.close(0u32.into(), b"done");
        authorized.close().await;
        intruder.close().await;
        server.close().await;
        serve_task.await.unwrap().unwrap();
    }
}
