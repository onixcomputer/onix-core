# Kache fleet blocked rollout evidence

Date: 2026-08-26

## Completed verification

The following checks passed before deployment:

- Kache typed Nickel fixtures;
- Kache positive and negative semantic settings tests;
- positive fleet membership and negative missing-machine and multiple-provisioner checks;
- generated configuration checks for Aspen1, Aspen3, and `britton-desktop`;
- the existing local-only Nix sandbox Kache checks;
- complete NixOS builds for all three nodes;
- Clan vars checks for all three nodes;
- Cairn validation and artifact gates.

The generated fleet has one shared bucket-scoped credential, one desktop provisioner, one daemon per node, and one managed Cargo wrapper per node. Aspen3 uses `/mnt/usb4-nvme/kache-nix/user-brittonr`.

## Runtime observations

The first Aspen smoke build found that the portable Cargo profile selected `cc` without installing a compiler driver. Commit `0480223a` adds the compiler driver to the wrapper and managed user environment. Complete builds passed again.

An Aspen1 library build then exercised the managed Cargo wrapper. Kache recorded one miss, three stored blobs, and 6.9 KiB of local content under cache key `16074cdedea0aa1cd848464db3ac5df920fb2334c900c59f1c124b78f19dfad1`.

A large concurrent rebuild filled niks3 queues and exposed a RustFS object-operation stall. Health endpoints remained live, but S3 HEAD requests timed out. The queues were stopped, RustFS was restarted one node at a time, and niks3 recovered to HTTP 200 in about 0.1 seconds. Queue state was not deleted.

Aspen3 also reached ZFS slop-space protection. Nix SQLite operations failed at zero dataset availability. The idle Nix daemon was restarted, normal Nix garbage collection ran, and only Kache rollout profile generations 50 and 54 were removed. ZFS stayed healthy. No unrelated snapshots were deleted.

## Exact blocker

The clean remote branch `origin/agent/site-celld-fleet-20260826` is concurrently deploying Celld services to the same three machines. Its current tip is `c776e3c0`. It has not reached `origin/main`.

Each Celld deployment replaces the Kache test closure. Each Kache deployment removes unmerged Celld services. The desktop provisioner also alternates the old per-machine Kache credential and this change's shared credential. That race caused the expected `SignatureDoesNotMatch` result on Aspen1.

The Kache test closures were removed from Aspen1 and Aspen3. Their prior accepted closures were restored. The Aspen3 Celld services are active again. The desktop had already been restored by the concurrent Celld rollout.

## Required continuation

Do not deploy or integrate this change until the Celld branch reaches `origin/main` or its owner explicitly releases the live machines. Then merge current `origin/main`, rerun focused checks and all three builds, deploy the combined closures, and repeat the cross-node library miss/hit test.
