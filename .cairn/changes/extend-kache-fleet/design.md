## Context

The accepted cache design runs a remote Kache daemon and managed Cargo wrapper only on `britton-desktop`. All three nodes already run RustFS and trust niks3. Aspen3 has little root-disk space but has ample USB4 storage.

## Decisions

### Decision: Run one daemon per node

**Choice:** Compose `kache-rustfs` on Aspen1, Aspen3, and `britton-desktop`. Each daemon uses its local RustFS endpoint and the shared `onix-kache` bucket authority.

**Rationale:** Local endpoints avoid a single ingress dependency. A shared content-addressed bucket lets all nodes reuse compatible artifacts.

### Decision: Keep one storage provisioner

**Choice:** Keep `britton-desktop` as the only bucket and IAM provisioner. Deploy the same generated bucket-scoped credential to all three daemons.

**Rationale:** One reconciler avoids concurrent IAM mutation. The shared credential has no authority outside `onix-kache`.

### Decision: Put machine policy in the system module

**Choice:** Export each generated Kache configuration at `/etc/kache-rustfs/config.toml`. The Home Manager Cargo wrapper uses this read-only file.

**Rationale:** The Clan instance remains the single source for endpoint, cache path, size, bucket, and prefix. Home Manager does not duplicate per-host policy.

### Decision: Preserve sandbox isolation

**Choice:** Keep Nix-owned Kache wrappers local-only. Do not expose RustFS credentials to derivations.

**Rationale:** Interactive system daemons can use remote authority without widening sandbox authority.

## Risks / Trade-offs

- A shared write credential means one compromised Kache daemon can alter objects in the Kache bucket. It cannot access other RustFS buckets.
- Aspen3 depends on the USB4 mount for its Kache daemon. Kache failure does not invalidate Cargo build results.
- Kache compatibility still depends on its compiler and toolchain key salt.
