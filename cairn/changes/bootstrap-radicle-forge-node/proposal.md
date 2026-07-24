## Why

No Onix-managed Radicle node or seed-backed HTTPS Git endpoint currently exists. The Bounded Exec publication, Lattice source cutover, multi-seed outage drill, and Radicle CI work therefore have no operational substrate to target. Building catalog or consumer behavior first would leave the pilot dependent on an imaginary endpoint.

`onix-core` owns concrete machine inventory, service packaging, deployment, secrets, firewall policy, monitoring, and backup operations. It must bootstrap the first least-authority Radicle node before the cross-repository forge pilot can publish source or change dependency transport.

## What Changes

- Package and pin a reviewed Radicle release at version `1.9.1` or later, including the node and read-only HTTP service required by the pilot.
- Add typed Nickel configuration and Nix service lowering for one explicitly selected bootstrap host, persistent storage, selective seeding, listener exposure, HTTPS Git access, monitoring, retention, backup, and restore policy.
- Deploy the initial node without repository delegate, CI, deployment, release-signing, cache-administration, or canonical-ref authority.
- Prove node restart persistence, exact-object publication/acquisition through the HTTPS gateway, rejected unsafe configurations, and clean restore from a BLAKE3-verified backup.
- Emit a bounded bootstrap receipt for OnixOS, Bounded Exec, and Lattice; do not claim that one node provides independent-seed availability.

## Impact

- **Files**: package and module definitions, typed Nickel schema/inventory, selected machine assignment, proxy/firewall configuration, focused checks, operator documentation, and bootstrap evidence.
- **Cross-repo output**: an accepted node identity and endpoint receipt becomes a prerequisite input to the OnixOS forge catalog and Bounded Exec publication.
- **Security**: the node holds only its own persistent node identity and selected repository data; delegate and CI authority remain elsewhere.
- **Testing**: positive module/evaluation and live bootstrap checks plus negative version, exposure, privilege, storage, endpoint, backup, and restore fixtures.
- **Non-goals**: this change does not provide the second independent seed, patch review, CI, canonical-ref enforcement, private-repository confidentiality, fleet migration, or GitHub-independent third-party inputs.
