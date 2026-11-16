## Phase 1: Implementation

- [x] [serial] Implement the upload endpoint with owner-only Tailscale admission, browser-safe request checks, no-replace storage, locked publishing and Calibre forwarding. r[onix.bookshelf.intake]
- [x] [serial] Add `trustedIps` to the Calibre module, refuse shared loopback addresses, and trust only the endpoint's dedicated source address on `britton-desktop`. r[onix.bookshelf.calibre_write]
- [x] [serial] Add behavioral, settings and generated-configuration checks and document the endpoint. r[onix.bookshelf.intake] r[onix.bookshelf.calibre_write]

## Phase 2: Deployment and verification

- [ ] [serial] Build `britton-desktop` from the deployed generation's source plus this change only, and review the closure, unit and dry-activation differences. r[onix.bookshelf.intake] r[onix.bookshelf.calibre_write]
- [ ] [serial] Activate the generation and upload a real book from the owner's devices into both libraries. r[onix.bookshelf.intake]
- [ ] [serial] Confirm refusals for foreign hosts and the Folio proxy, and that Calibre still refuses writes relayed from `127.0.0.1`. r[onix.bookshelf.intake] r[onix.bookshelf.calibre_write]
