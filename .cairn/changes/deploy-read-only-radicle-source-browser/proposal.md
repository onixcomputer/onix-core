## Why

The managed Radicle gateway provides native replication and exact read-only Git acquisition. It does not provide a human-readable source view.

OnixOS change `declare-read-only-radicle-source-browser` defines the portable policy and route contract. `onix-core` owns the concrete package, service, publication, proxy, monitoring, backup, and rollback effects.

Radiant Forge revision `301216829a5bc35afc635b764db6a340205ca9f4` is a behavior reference only. Its all-rights-reserved source cannot be reused.

## What Changes

- Review licensed published source-browser components against the accepted OnixOS contract.
- Select a component only when it can enforce every route, identity, license, and resource boundary.
- Generate immutable static HTML snapshots for exact admitted RID and Git object pairs.
- Run any external generator through Bounded Exec with explicit inputs and limits.
- Admit generated trees through Bounded Tree before publication.
- Publish immutable snapshots and one explicit current pointer through durable publication mechanics.
- Serve only admitted browser paths through the existing HTTPS boundary.
- Keep upload-pack, browser rendering, publication, and repository governance as separate authorities.
- Add monitoring, retention, incident, rollback, and redaction-safe receipts.

## Impact

- **Specs**: `radicle-forge-operations`
- **Files**: package pins, typed profiles, generation wrapper, Nix modules, Nginx routes, publication state, fixtures, checks, evidence, and runbooks
- **Dependencies**: accepted OnixOS browser contract, Bounded Exec, Bounded Tree, and durable file publication
- **Deployment**: public browser routes remain disabled until exact live evidence passes

## Non-Goals

- No receive-pack, repository mutation, issues, patches, review, comments, login, or private browsing.
- No ambient repository scan or local marker-file publication.
- No direct serving from mutable working trees.
- No copying or translation of Radiant Forge source, templates, assets, or tests.
- No claim that rendering proves source correctness, review, safety, availability, or release readiness.
- No replacement of Radicle, Git smart HTTP, Kiln, or repository governance.

## Verification Expectations

Completion requires one admitted public RID and exact Git object to publish bounded static views. Every unknown, private, writable, stale, unsafe, or over-limit path must fail closed.
