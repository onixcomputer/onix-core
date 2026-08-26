## Context

Bookshelf is a Next.js application with Cloudflare R2 and Node filesystem adapters. Celld v0.3.0 runs Worker bundles and static assets, but its documented alpha boundary excludes R2 bindings. Bookshelf also requires Workers Cache, rate-limit, service, and asset bindings in its Cloudflare configuration. Running that bundle on Celld would therefore fail closed.

`britton-desktop` already provides a quota-managed ZFS datapool and Tailscale. The upstream filesystem adapter stores published books, profiles, and reading positions in one directory. The upstream sync command converts owned EPUB and PDF files into that published directory.

## Decisions

### 1. Use the upstream Node filesystem mode

**Choice:** Run the pinned upstream application as a Node server. Do not patch in an emulated R2 binding or run it on Celld.

**Rationale:** This path uses an upstream-supported adapter and keeps external runtime types outside the local service policy. Celld remains unchanged.

### 2. Keep storage and serving authority separate

**Choice:** Use `/datapool/bookshelf/source` for operator-owned inputs and `/datapool/bookshelf/library` for generated application state. The system service can read source data only through the explicit sync command and can read and write the published library.

**Rationale:** The generated library is replaceable from source books, while profiles and reading positions inside it require backup. Separate paths make both boundaries visible.

### 3. Expose only the Tailnet listener

**Choice:** Bind to `100.110.43.11` on a dedicated port and add that port only to `networking.firewall.interfaces.tailscale0.allowedTCPPorts`.

**Rationale:** Bookshelf has no authentication. A global listener or firewall rule would disclose every book and profile.

### 4. Package one immutable revision

**Choice:** Fetch revision `8888795162ff76285f246957cc34cc9988253a60`, build the filesystem artifact, and retain the MIT license and upstream notices.

**Rationale:** The deployment must not follow a moving branch. The package and application source remain reproducible.

### 5. Keep operator publishing explicit

**Choice:** Install a `bookshelf-sync` command with fixed configuration and image tooling. Do not watch arbitrary directories or publish automatically.

**Rationale:** Publishing changes the complete visible catalog. An explicit command preserves operator intent and provides a clear failure boundary.

## Risks / Trade-offs

- The application has no authentication. Tailnet membership is the access boundary.
- The initial deployment is single-node. A desktop outage makes the library unavailable.
- Reading positions are last-write-wins when two devices use one profile.
- The library is cleartext on the mounted datapool. Host and backup protection remain required.
- Bookshelf and its large JavaScript dependency closure increase build and update cost.
