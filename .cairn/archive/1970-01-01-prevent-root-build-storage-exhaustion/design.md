## Context

The root ext4 filesystem contains `/home/brittonr`, including `~/git` and `~/.cache`. The 4 TB data drive provides `datapool/cargo-target` at `~/.cargo-target` and `datapool/kache-nix` at `/var/cache/kache-nix`. Global Cargo configuration uses the shared target, but many verification rails deliberately override it with a repository-local `target` for isolation. Those outputs therefore bypass the ZFS target dataset.

## Decisions

### 1. Put the complete Git workspace on ZFS

**Choice:** Create `datapool/git`, mount it at `/home/brittonr/git`, and enforce a 600 GiB quota.

**Rationale:** This catches current and future relative `CARGO_TARGET_DIR=target` overrides without forcing incompatible worktrees to share one Cargo lock or artifact graph. It also protects root independently of repository behavior.

### 2. Bound shared build datasets

**Choice:** Cap `datapool/cargo-target` at 1500 GiB and `datapool/kache-nix` at 64 GiB.

**Rationale:** Build caches are disposable and must not consume the complete data pool. The limits leave capacity for Nix, Mantle, backups, and temporary storage.

### 3. Isolate interactive Kache state

**Choice:** Set the Home Manager cache path to `/var/cache/kache-nix/user-brittonr` while leaving Nix builders on the machine-owned cache path contract.

**Rationale:** Both paths remain on ZFS, but user state does not depend on `~/.cache` and does not reuse the user path from inside Nix sandboxes.

### 4. Prune only verified stale targets

**Choice:** Weekly cleanup removes a directory only when it is named `target`, contains Cargo's `CACHEDIR.TAG`, is ignored by Git, and has no file modified in 21 days. The job skips all cleanup while Cargo or rustc is active. Standalone `~/.cargo-target-*` directories use the same marker and age checks.

**Rationale:** The marker and ignore checks exclude tracked fixtures. The activity and modification checks reduce races with builds.

### 5. Bound journals separately

**Choice:** Set `SystemMaxUse=1G`, `RuntimeMaxUse=512M`, and a 14-day retention period.

**Rationale:** Journals were not the primary cause, but an explicit limit removes one unbounded root consumer.
