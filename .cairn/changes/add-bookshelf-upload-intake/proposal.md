## Why

Adding a book to the private libraries on `britton-desktop` needs root on that machine: `bookshelf-import` for Bookshelf, and a stop, `calibredb add`, start cycle for Calibre because the content server holds Calibre's library lock and accepts no anonymous writes. The owner wants one endpoint to send books to from a phone or another computer.

## What Changes

- Add an opt-in upload endpoint to the `bookshelf` module: `PUT /<file name>` with an EPUB or PDF body, or a browser page that does the same. It stores the book in the source directory, publishes it, and offers it to a configured Calibre content server.
- Admit only untagged Tailscale devices owned by the same user as the server, decided by tailscaled's local API for every request; no identity is configured in the repository.
- Add `trustedIps` to the `calibre-server` module and trust only the endpoint's dedicated loopback source address, `127.0.0.2`.
- Serialize publishing: `bookshelf-publish.service` and the endpoint take one lock around `bookshelf-sync`.
- Enable the endpoint on `britton-desktop` at `100.110.43.11:39301`.

## Impact

- **Files**: `modules/bookshelf` (intake service, settings, schema, settings tests, `intake.py`), `modules/calibre-server` (trusted addresses, validation, settings tests), `inventory/services/services.ncl`, `inventory/services/fixtures/bookshelf-validation.ncl`, `flake-outputs/_module-checks.nix`, `tests/test_bookshelf_intake.py`, `docs/bookshelf.md`.
- **Runtime**: one new unit, `bookshelf-intake.service`; `calibre-server.service` restarts once to gain `--trusted-ips`; `bookshelf-publish.service` gains the lock.
- **Testing**: behavioral pytest suite with mutation evidence, settings and generated-configuration checks, scoped build from the deployed source, and real uploads through the Tailnet.
