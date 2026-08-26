# RustFS build cache rollout evidence

Date: 2026-08-26

Hosts: `aspen1`, `aspen3`, and `britton-desktop`

## Verification before deployment

The following checks passed:

- the pure bucket-policy positive, negative, and least-authority checks;
- Kache and niks3 Nickel type fixtures;
- Kache and niks3 pure semantic tests;
- Kache and niks3 generated-configuration checks;
- the existing three Kache Nix sandbox checks before and after the change;
- complete NixOS builds for Aspen1, Aspen3, and the desktop;
- Clan vars checks on all three hosts;
- repository Cairn validation.

The reviewed niks3 input is `v1.8.0`, locked at upstream revision `61501c4223ec3ad804c20625128cab1155166041`.

## Deployment handling

Aspen1 initially had load near 80 from unrelated Rust builds. The closure copied successfully, but systemd D-Bus timed out before activation. No reboot or unrelated task termination was used. After those builds drained, the direct declarative switch completed. The known unrelated `radicle-ci-runner.service` namespace failure remained.

Aspen3 and the desktop deployed from local builds. Another active desktop rollout briefly replaced the first cache activation. The cache closure was reapplied after that task finished.

A Kache probe auto-started a user-owned daemon while configurations changed. The final module uses `Restart=always`, so the system service reclaims the daemon lock after a clean competing exit. Only probe-created daemon processes were terminated. The final daemon runs in `/system.slice/kache-rustfs.service`.

## Kache results

- `kache-rustfs.service` is active as `brittonr:users`.
- `kache-rustfs-storage-provision.service` is active and complete.
- The credential file is `brittonr:users` mode `0400`.
- Home Manager no longer installs a second `kache.service` user unit.
- A temporary Cargo library produced one isolated cache artifact.
- Kache pushed that artifact to RustFS, removed its local test cache, and pulled it into a new cache.
- The pull restored five local cache files.
- A forced daemon stop drained uploads, and systemd started a new daemon process.
- The final service reports `ExecMainStatus=0`.
- The final `NRestarts=49` includes the deliberate ownership-recovery test and the earlier probe race. It was not a crash loop after ownership stabilized.

The normal desktop daemon also began uploading new artifacts from active interactive Rust builds. Existing local cache contents were not bulk-uploaded by the acceptance probe.

## niks3 results

- `niks3-storage-provision.service`, `niks3.service`, `niks3.socket`, `niks3-auto-upload.socket`, and PostgreSQL are active on Aspen1.
- niks3 listens only on `100.100.103.95:39400`.
- The active nftables policy admits port `39400` through `tailscale0`.
- The server runs as `niks3:niks3`, with `NRestarts=0` and `ExecMainStatus=0` after restart.
- S3 access, secret, and signing files are `niks3:niks3` mode `0400`.
- The shared upload token is `root:niks3-uploaders` mode `0440` on all three hosts.
- All three hosts contain the private substituter URL and the dedicated public signing key.
- `nix-cache-info` returned a valid cache response.

Aspen1 uploaded `/nix/store/cp7rbc7czmkcw8wxabd1k1l303fkz9c8-niks3-runtime-probe.txt`. The desktop did not have this path. It copied the path through the read proxy and verified the signed content. An upload with an empty token failed, and its narinfo remained absent.

After `niks3.service` restarted, Aspen3 fetched the accepted probe narinfo. The auto-upload daemon on Aspen3 was also actively sending real post-build paths through its durable queue. Its acceptance probe entered that queue behind the existing upload backlog.

## Storage authority

The live `niks3-nix-cache` policy contains only explicit bucket metadata, object read/write/delete, and multipart actions for:

- `arn:aws:s3:::onix-niks3`
- `arn:aws:s3:::onix-niks3/*`

The live `kache-rustfs-kache-remote` policy contains the same explicit action classes only for:

- `arn:aws:s3:::onix-kache`
- `arn:aws:s3:::onix-kache/*`

Neither policy contains `s3:*`, and the buckets do not overlap.

## Final storage health

The RustFS live endpoint returned success through Aspen1, Aspen3, and the desktop after uploads and service restarts.
