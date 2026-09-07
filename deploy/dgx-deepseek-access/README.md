# DeepSeek access over Iroh

## Live service

The Spark at `192.168.1.244` serves `deepseek-v4-flash-0731-ablit-100` through vLLM on port `8888`.
This deployment leaves vLLM and its second Spark unchanged.

The access path is:

```text
OpenAI client -> local dumbpipe :9338 -> Iroh -> Spark dumbpipe
             -> loopback Nginx :18888 -> loopback vLLM :8888
```

Dumbpipe owns encrypted transport, NAT traversal, and relay fallback.
Nginx owns API-key checks and the allowed HTTP routes.
A ticket identifies the server. It does not grant API access.
Each recipient needs a separate API key.

The gateway permits only these operations:

- `GET /v1/models`
- `POST /v1/chat/completions`, including streaming

Other routes return `404`. Other methods on these routes return `405`.
Missing and unknown keys return `401` before Nginx forwards a request.
The gateway removes the authorization header before it forwards the request to vLLM.
It does not log request bodies or access records.
It does not provide per-user quotas or billing.

## This workstation

The enabled `deepseek-iroh-client.service` provides this OpenAI base URL:

```text
http://127.0.0.1:9338/v1
```

The private client files are outside this repository:

```text
/home/brittonr/git/.runtime/deepseek-iroh/ticket
/home/brittonr/git/.runtime/deepseek-iroh/api-key
/home/brittonr/git/.runtime/deepseek-iroh/curl-auth.conf
```

Use the contents of `api-key` as the OpenAI API key.
The `curl-auth.conf` file supplies the same header without a key in process arguments:

```sh
curl --config /home/brittonr/git/.runtime/deepseek-iroh/curl-auth.conf \
  http://127.0.0.1:9338/v1/models
```

The existing Qwen mesh on port `9337` remains unchanged.

## Give someone access

Use SSH as `brittonr@192.168.1.244` with the existing Framework key.
The server keeps its private state in `/home/brittonr/.ds-iroh`.
The short path avoids the Unix socket path limit encountered with Mesh-LLM.

On the Spark, generate a separate key for the recipient:

```sh
umask 077
credential_bytes=32
(set -C; openssl rand -hex "$credential_bytes" > ~/.ds-iroh/recipient.api-key)
```

Add that key to `~/.ds-iroh/api-keys.conf`:

```sh
IFS= read -r recipient_key < ~/.ds-iroh/recipient.api-key
printf '"Bearer %s" recipient;\n' "$recipient_key" >> ~/.ds-iroh/api-keys.conf
```

Use a distinct file and label for each recipient.
Validate the configuration before activation:

```sh
~/.local/share/deepseek-access/nginx/bin/nginx -e stderr -t \
  -c ~/.local/share/deepseek-access/nginx.conf -p ~/.ds-iroh
```

After validation succeeds, restart both services:

```sh
systemctl --user restart deepseek-api-gateway.service deepseek-iroh.service
```

Send the recipient their key and the contents of `~/.ds-iroh/ticket` through a private channel.
Do not send `dumbpipe.env`, which contains the server identity secret.
Do not share the existing workstation key with other recipients.

The recipient installs Dumbpipe `v0.39.0` from the official release for their platform.
The recipient then runs:

```sh
IFS= read -r ticket < ./ticket
dumbpipe connect-tcp --addr 127.0.0.1:9338 "$ticket"
```

Their client uses `http://127.0.0.1:9338/v1`, their assigned API key, and the exact DeepSeek model name.
Tailscale, SSH access, and a public HTTP listener are not required on their device.
The ticket contains only the stable endpoint ID. Iroh resolves its current address.

To revoke access, remove that recipient's entry from `api-keys.conf`.
Validate the configuration, then restart both services with the commands shown earlier.
A restart also closes existing streams. A graceful Nginx reload can leave old streams active.

## Deployment and pins

The server runs two enabled user services:

- `deepseek-api-gateway.service`
- `deepseek-iroh.service`

User linger is enabled. Passwordless sudo is not required.
The Nginx configuration is `~/.local/share/deepseek-access/nginx.conf`.
Dumbpipe reads its persistent identity from the private `~/.ds-iroh/dumbpipe.env` file.
The gateway binds only to `127.0.0.1:18888`.

Dumbpipe source: `n0-computer/dumbpipe`, commit `6c4990dc0c49f3c93947ef6ebeafcf846a6532e0`, release `v0.39.0`.
The deployed binaries match these GitHub release digests:

```text
linux-aarch64 archive SHA-256: 8cd099afe80c69ac58bfbc975b28e29d41caea141f3dd396457345a739836a0e
linux-x86_64 archive SHA-256: 9ac5e71983eba4cf4f47e92e4694dad0f0133abba4f14dd2a2a8428cece88fef
```

SHA-256 matches the release API contract. This is not a new hash-format choice.
Nginx comes from the existing Onix lock's nixpkgs revision `9cf7092bdd603554bd8b63c216e8943cf9b12512`.
The server retains its Nix GC root at `~/.local/share/deepseek-access/nginx`.

The user service files use the reviewed host paths and ports directly.
Install server units under `~/.config/systemd/user/`, then run `systemctl --user daemon-reload`.
Install the Nginx configuration before either service starts.
Provision private key files before activation. Missing files fail startup.

## Validation and limits

See [evidence.md](evidence.md) for the accepted and rejected probes.
Both direct-capable Iroh access and loopback-UDP relay access passed.
No reboot or external recipient device test was performed.

The original LAN vLLM endpoint still listens on `0.0.0.0:8888` without HTTP authentication.
This deployment does not change that existing LAN exposure or prove its public reachability.
Anyone with host access can still use that original endpoint directly.

The staged Tailscale daemon and HTTPS service are disabled and inactive.
Mesh-LLM is not part of the accepted path. Its owner allowlist did not protect HTTP inference in the tested version.
The failed Mesh-LLM trial remains stopped. Its package and private diagnostic files remain on the Spark for review.

## Stop access

On the Spark:

```sh
systemctl --user disable --now deepseek-iroh.service deepseek-api-gateway.service
```

On this workstation:

```sh
systemctl --user disable --now deepseek-iroh-client.service
```

The original DeepSeek service remains unchanged.
