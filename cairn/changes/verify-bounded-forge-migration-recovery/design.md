# Design: Post-migration recovery and observation

## Success contract

Completion requires an encrypted archive created after the migrated COB refs reached Aspen, complete state and recovery-input manifests verified in a clean root, recovered node identity and private fixture semantics, ordinary Radicle evaluation of the restored solved issue and archived patch, exact importer `parent` signed refs, cleanup of all plaintext restore roots, and matching healthy probes at least 24 hours apart. Canonical Bounded Exec `main` must remain unchanged.

False completion includes selecting a pre-migration archive, checking refs without complete manifest verification, evaluating the live repository instead of an isolated restore, treating imported review text as native approval, starting a duplicate restored node, leaving keys or restored storage behind, measuring less than 24 hours, accepting an active CI outbox, or claiming canonical admission, durability beyond the observed interval, or release readiness.

## Bounded execution

The existing Borg job stops and resumes only its recorded Aspen Radicle services, verifies the staged private/public key pair and pinned fingerprint before restart, mounts `/var/lib/radicle` read-only inside the backup unit, encrypts to the restricted desktop repository with `repokey`, and removes plaintext staging in its post-hook.

The deployed restore verifier extracts the latest archive into `/var/lib/radicle-restore-check`, regenerates complete BLAKE3 manifests, verifies identity and repository count, performs the existing private-pilot semantic check, and removes the root through an exit trap.

A second operator probe extracts the same archive into a distinct clean root. It adds `safe.directory` only for the restored Bounded Exec repository because extraction preserves the `radicle` owner while the verifier is root. It checks exact Git refs, refreshes issue/patch caches with `--no-announce`, and evaluates the built-in objects through ordinary `rad issue` and `rad patch`. It never starts a node and removes the script, Borg runtime, and restore root through traps.

## Observation

The initial and delayed probes bind canonical `main`, migrated issue/patch refs, importer sigrefs, local/Aspen/desktop convergence, public HTTPS, active production services, empty CI outbox, restore-root cleanup, one local node, and at least 56 GiB backup headroom. The delayed probe fails if its measured interval is below the named 24-hour minimum.

## Boundaries

Complete manifests prove byte-exact persisted state under the checked manifest implementation. Built-in CLI output proves only the restored evaluator observation. Neither proves source-host completeness, actor authenticity, approval equivalence, arbitrary Radicle correctness, canonical eligibility, post-window durability, secure deletion, or release readiness.
