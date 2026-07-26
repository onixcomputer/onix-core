# Private Radicle pilot evidence — 2026-07-25

## Publication

- RID: `rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg`;
- visibility: `private`;
- reviewed commit: `ff4ff027817465b1bb04251a8a98db42cc610b0c`;
- source archive BLAKE3: `514904bdcf5f23b0813c567efbc8b6732248de94482037a58011bfff3fc26853`;
- identity revision/root: `7fe3c9bd6a2d01a8317acb44ba386988375898da` / `bf5e168201192881cf34e9ff7f7c39ee42dc7d62`;
- Author delegate signed refs: `fc566eae3a5954df30d9499e0f85fe1b45a34d46`;
- identity JSON BLAKE3: `a080d88d7b9cd58bf08130308c487b968863191caafea7f7f0e973471a2ed3b2`.

The repository is a non-secret fixture. The explicit privacy set contains Aspen DID `did:key:z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`, desktop DID `did:key:z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG`, and authorized client DID `did:key:z6MkwGV7ypRii8RjoSotmUbuKU4MwGQf3iw8AdhuJkkyD4wd`. Denied client DID `did:key:z6MksVCc4QAvmZrZXX2MWoGwo9XqDUbiFjsjDZuRZrbgEu6h` is absent.

## Deployment and exact policy

The checked implementation revision is `956cc432ad990c346326718d3a94c512e9020427`, rebased over the separately reviewed execution-graph public-source admission.

- final Aspen closure: `/nix/store/kjsrz3h86rk6503wk3xdq1rq3wckh8ly-nixos-system-aspen1-26.11.20260629.7a1a647`;
- final desktop closure: `/nix/store/lvsf8gfpcbg4h6psk283n41x1vc0r4iq-nixos-system-britton-desktop-26.11.20260629.7a1a647`;
- both base units lower exactly three public RIDs plus the private fixture;
- HTTPS remains exactly the three public RIDs and CI remains Bounded Exec only;
- the final base policy replaces temporary execution-graph runtime overrides with one declarative four-RID native set.

Concurrent execution-graph staging initially exposed conflicting three- and four-RID reconcilers. Acceptance was withheld while they alternated removal and addition. The merged implementation classifies execution graph as public, the fixture as private, and admits both through one exact declarative union.

Both seed stores contained canonical and Author namespace `main` at `ff4ff027817465b1bb04251a8a98db42cc610b0c`, identity revision `7fe3c9bd6a2d01a8317acb44ba386988375898da`, and Author signed refs `fc566eae3a5954df30d9499e0f85fe1b45a34d46`.

## Authorized and denied clients

Two fresh copies of the pre-acquisition authorized profile were started loopback-only and connected directly to one seed each. Aspen and desktop clones both reproduced:

- commit `ff4ff027817465b1bb04251a8a98db42cc610b0c`;
- source archive BLAKE3 `514904bdcf5f23b0813c567efbc8b6732248de94482037a58011bfff3fc26853`;
- signed-reference minimum feature `parent`.

Two fresh denied profiles connected directly to one seed each. Both remote inventory responses omitted the private RID. Both direct clone attempts failed at the fetch handshake with no checkout directory created.

These observations are bounded to Radicle 1.9.1, the tested identities, seed endpoints, and direct acquisition path. They do not prove global metadata secrecy or traffic-analysis resistance.

## HTTPS exclusion

- private upload-pack info refs: HTTP `404`;
- private receive-pack: HTTP `404`;
- admitted Bounded Exec upload-pack info refs: HTTP `200`.

The CI policy remains Bounded Exec only. The private RID is native source-serving only.

## Backup and recovery

Encrypted Borg archive `aspen1-britton-desktop-2026-07-25T22:22:31` left `aspen-primary-site` for the restricted desktop repository.

Complete state manifest:

- BLAKE3 `915134d3d2245cf6b823558fa32abc04c04346ee05c635eae28600f78920bff1`;
- records `303242`;
- bytes `57970684391`.

Recovery-input manifest:

- BLAKE3 `f07e19303e8880b01b2baac97cf11f2f207030fdbe64224d6d26e6a940e3dddd`;
- records `6`;
- bytes `72363700`.

Clean-root restore verified repository count `6763`, Aspen node ID and fingerprint, complete manifests, the private canonical and delegate commits, identity revision, signed refs, and exact source BLAKE3. The restore root and Borg runtime root were absent after the trap completed.

## Validation and claim boundary

Focused primary and replica checks passed with positive and negative fixtures for missing, malformed, duplicated, overlapping, unknown, and HTTPS-widened private sets. Both reviewed host closures built. The enhanced restore verifier is statically bound to the private identity/source and passed live semantic recovery. Typed receipt BLAKE3 is `f831c1c24e507455b2b5a585da3b5ac3682f7ac2322ed63127ec40eae8c8ea57`.

## Integration gate

The private mechanism and live evidence are complete, but repository integration remains deliberately open. The branch is layered over staged execution-graph public admission whose producer change still records an incomplete delegate quorum. Merging or archiving this private change first would publish that unaccepted public source transitively. Task V5 therefore remains open and no private-pilot push is permitted until execution graph is either accepted with its producer governance or removed from the branch.

A broad `nix flake check -L` reached the existing aarch64-under-QEMU `nix-wasm-plugins` build and was stopped after more than 30 minutes in an active `nickel-lang-parser` build script; no deterministic failure was observed. Focused positive/negative policy checks, the private receipt check, and both x86_64 host closure builds passed.

This evidence does not prove production-secret confidentiality, global metadata secrecy, anonymity, traffic-analysis resistance, multi-delegate private governance, secure deletion, automatic failover, geographic independence, source correctness, protocol-enforced CI, release readiness, or whole-fleet migration readiness.
