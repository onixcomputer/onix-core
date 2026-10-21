# Iroh access evidence — 2026-09-07

## Accepted boundary

Host: `spark-e442`, `192.168.1.244`, user `brittonr`.
Backend: the existing vLLM service on `127.0.0.1:8888`.
Transport: Dumbpipe `v0.39.0` over Iroh, with Nginx API-key checks before backend access.
Client: this workstation, through `127.0.0.1:9338`.

The backend returned its model list before any deployment changes.
The backend health endpoint returned `200` after deployment.
No command restarted vLLM or changed its model configuration.

## Results

| Probe | Observed result |
| --- | --- |
| ARM and x86 Dumbpipe archives | Both match their published SHA-256 digests |
| Nginx configuration | `nginx -t` passes on the Spark |
| Server and client units | `systemd-analyze --user verify` passes |
| Authorized model list through Iroh | HTTP `200`, expected DeepSeek model |
| Authorized streaming chat through Iroh | HTTP `200`, content `SPARK-IROH-OK`, finish reason `stop`, then `[DONE]` |
| Missing API key | HTTP `401` |
| Wrong API key | HTTP `401` |
| Administrative route `/reset_prefix_cache` with a valid key | HTTP `404` |
| `POST /v1/models` with a valid key | HTTP `405` |
| Malformed chat JSON with a valid key | HTTP `400` |
| Temporary recipient key | HTTP `200` before revocation |
| Same temporary key after removal and service restart | HTTP `401` |
| Retained workstation key after that restart | HTTP `200` |
| Gateway port through the LAN address | Connection refused, curl status `000` |
| Relay fallback with an endpoint-ID-only ticket | HTTP `200` for the model list |
| Tailscale services | Both disabled and inactive |
| Existing workstation Qwen mesh | Still active |

The relay probe used a separate Dumbpipe process.
It bound its only UDP sockets to `127.0.0.1` and `::1`.
`ss -ulnp` confirmed both loopback sockets for that process.
Thus that request did not use a direct UDP path to the Spark.
The probe service stopped after the check.

The server transport and gateway are enabled and active with zero automatic restarts at final inspection.
Their observed memory use was approximately 4 MB and 2 MB, respectively.
These are point observations, not capacity benchmarks.

The server state directory has mode `0700`.
The API key, authorization map, and identity environment file have mode `0600`.
The workstation state directory also has mode `0700`, with private key and client configuration files at `0600`.
The ticket is not an API credential.

The local systemd validator also reports an unrelated executable-bit warning for `pueue-gc.timer`.
That warning does not concern these units.

## Rejected Mesh-LLM candidate

Mesh-LLM `v0.72.2` and OpenAI adapter `0.1.2` successfully routed a DeepSeek streaming response.
However, the negative access test failed.

The seed used an owner key, `--owner-required`, `--trust-policy allowlist`, and a trust entry for the approved workstation owner.
A separate client used the valid invite but no owner key or owner certificate.
That client received HTTP `200` and the complete `SPARK-IROH-OK` response.

The pinned source explains this behavior in `crates/mesh-llm-host-runtime/src/mesh/mod.rs`:

- `stream_allowed_before_admission` admits `STREAM_ROUTE_REQUEST` and `STREAM_TUNNEL_HTTP` before peer admission.
- `admitted_mesh_stream` returns early for those stream types.

The tested owner allowlist therefore did not protect this HTTP inference path.
The gateway was stopped immediately after the failed denial test.
The accepted deployment replaces Mesh-LLM with Dumbpipe and separate API-key checks.
No recipient grant depends on the failed Mesh-LLM trust policy.

## Other constraints

The workstation Pueue daemon stopped because its state filesystem ran out of space.
Its journal reports `Failed to write temp file while saving state` and `No space left on device (os error 28)`.
Later operations used bounded SSH commands and transient user services.
No unrelated build outputs were removed.

The initial ARM adapter build also met a crates.io HTTP `403`.
A hash-checked local vendor cache with an identical upstream `Cargo.lock` allowed the trial adapter build to finish.
That adapter is not part of the accepted deployment.

## Commit-hook recovery

The first commit attempt ran the repository-wide formatter against unrelated local work.
It changed seven Collie assets, three Kagi files, and the untracked `pkgs/aspen-uma-helper/flake.nix`.

The seven Collie files were restored from their unchanged index snapshots.
The three Kagi files were restored from a Nix source snapshot.
Formatting that snapshot reproduced the hook output byte-for-byte before restoration.

The untracked UMA flake changed from 4,548 to 4,547 bytes.
The available older Nix snapshot does not contain the current UMA changes, so it was not used for restoration.
That formatter change remains outside this deployment commit.
A backup of the hook output remains under the private workstation state directory in `formatter-recovery/after-hook/`.
No `flake.lock` file was edited.

## Non-claims

- No reboot test or test from a recipient's external device was performed.
- The relay probe proves a working relay path, not every NAT or firewall combination.
- The gateway adds no per-user rate limits, billing, or quotas.
- The existing unauthenticated LAN listener on port `8888` remains unchanged.
- The host owner remains trusted and can access the backend or read its keys.
- The tests do not prove the absence of all defects in Dumbpipe, Iroh, Nginx, or vLLM.
