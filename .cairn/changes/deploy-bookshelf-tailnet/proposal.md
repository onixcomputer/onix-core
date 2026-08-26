## Why

Bookshelf provides a browser and OPDS library for owned EPUB and PDF files. Its Cloudflare deployment requires R2 bindings, which Celld v0.3.0 does not support. Bookshelf also ships a Node filesystem mode that matches the private workstation and ZFS storage boundary.

## What Changes

- Pin and package `murerkinn/bookshelf` at an immutable revision.
- Add a typed Clan service that runs Bookshelf in Node filesystem mode.
- Store source books, generated library data, profiles, and reading positions under `/datapool/bookshelf`.
- Bind the application to the desktop Tailnet address and admit its port only through `tailscale0`.
- Add an operator command that publishes owned EPUB and PDF files from the private source directory.
- Add positive and negative contract checks, generated-service checks, and runtime evidence.
- Record Bookshelf in `README.md` as a reviewed reference codebase.

## Impact

- **Machines**: `britton-desktop` gains one private Bookshelf service.
- **Storage**: `/datapool/bookshelf` becomes persistent application state and requires backup.
- **Network**: one HTTP port is admitted on `tailscale0`; no global firewall port is opened.
- **Security**: Bookshelf has no application authentication, so the service remains Tailnet-only.
- **Testing**: package checks, contract fixtures, generated NixOS policy checks, Cairn gates, and a full desktop build.
