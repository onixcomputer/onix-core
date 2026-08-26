# Bookshelf runtime rollout evidence

Date: 2026-08-26

Host: `britton-desktop`

Endpoint: `http://100.110.43.11:39300`

## Build and validation

The following checks passed after the branch merged current `origin/main`:

- `module-registry-sync`
- `bookshelf-package`
- `bookshelf-settings`
- `bookshelf-generated`
- the complete `britton-desktop` NixOS build
- `clan vars check britton-desktop`
- Cairn validation with the repository policy

The package install check generated nine demo books. It completed a dry-run sync, rejected an unknown option, and served the built application over HTTP.

## Deployment

`clan machines update britton-desktop --upload-inputs` installed the package and service.

The first start exposed a systemd ordering fault. The service tried to enter `/run/bookshelf/app` before `ExecStartPre` created it. Commit `066ae92c` moved the initial working directory to `/run/bookshelf` and added a generated-configuration regression check. A second complete desktop build and deployment passed.

## Runtime results

- `bookshelf.service` is `active`.
- The service runs as `bookshelf:bookshelf`.
- `NRestarts=0` and `ExecMainStatus=0` after the corrected deployment.
- The only listener is `100.110.43.11:39300`.
- `/datapool/bookshelf/source` is `bookshelf:bookshelf` mode `0700`.
- `/datapool/bookshelf/library` is `bookshelf:bookshelf` mode `0700`.
- The Tailnet endpoint returned the Bookshelf HTML page.
- Aspen3 fetched the same page through the Tailnet endpoint.
- `127.0.0.1:39300` rejected a connection because the service does not bind loopback or a public address.
- A non-root `bookshelf-import` call failed as required.
- The active nftables program admits TCP port `39300` through `tailscale0`.

## Boundaries

This deployment contains no owned books yet. Operators must use `bookshelf-import` for EPUB or PDF input. The source directory remains the backup boundary. The generated library is replaceable output.
