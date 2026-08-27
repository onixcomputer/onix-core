# Isolated niks3 and recovery runtime evidence

Date: 2026-08-26

## Deployment

The final configuration was built for Aspen1, Aspen3, and `britton-desktop`. Each host switched to its verified closure.

Aspen1 runs two distinct RustFS processes:

- `rustfs.service` on `100.100.103.95:39000` for the distributed coordination cluster;
- `rustfs-niks3-cache.service` on `100.100.103.95:39500` for disposable niks3 objects.

The isolated service uses `/var/lib/rustfs-niks3-cache`, separate root credentials, CPU weight 10, I/O weight 10, and nice value 10. The niks3 server also uses CPU and I/O weight 10 with one CPU quota. Port 39500 is admitted only through `tailscale0`.

All three distributed peers were restarted together after the final switch. This cleared stale boot epochs. The distributed namespace and isolated cache namespace then returned HTTP 200.

## Upload admission and isolation

Automatic uploader sockets and services are inactive on all three nodes. No `/run/niks3-maintenance-window` marker remains.

A real Nix derivation completed while automatic uploads were disabled. The observed queue stayed at 31 rows, and the uploader socket and service stayed inactive.

Starting the uploader without a marker produced `ConditionResult=no`. No queue row changed.

A marked Aspen3 maintenance drain used `--batch-size 1` and one upload worker. Queue depth decreased from 31 to 22 rows. During 20 consecutive samples:

- all three distributed RustFS endpoints returned HTTP 200;
- all three lab Celld endpoints returned HTTP 200;
- both Site Celld endpoints returned HTTP 200;
- niks3 returned HTTP 200.

The run uploaded a partial 781.7 MB closure without sending object traffic to the distributed RustFS process. Stopping during that large object preserved the remaining queue rows.

Final durable queue metrics were:

- `britton-desktop`: 2,663 paths;
- Aspen1: 80 paths;
- Aspen3: 22 paths.

These queues remain for later admitted maintenance windows.

## Monitoring

Every node exports `onix_niks3_upload_queue_paths` through the node-exporter textfile collector. The metric uses a quoted `node` label.

Prometheus loaded the blackbox job and reported nine successful storage and coordination probes. Alert rules cover:

- waiting and critical niks3 queues;
- failed or slow storage and coordination probes;
- low build-storage capacity;
- failed systemd units and frequent restarts.

## Backup and restore

Aspen1 created a 21 MB compressed PostgreSQL dump. The managed uploader stored it with a BLAKE3 sidecar in `onix-niks3-metadata-backup`.

The desktop created a quiesced object snapshot under `/datapool/rustfs-authority-backup/snapshots/20260827T012055Z`.

The snapshot contained 928 files and used 47 MB. It included:

- `onix-celld-lab`;
- `onix-site-celld`;
- `onix-niks3-metadata-backup`.

It excluded Kache and niks3 cache objects.

The object restore probe verified every BLAKE3 manifest entry. It restored one object through `onix-restore-probe`, compared the bytes, and removed the probe bucket.

The off-host PostgreSQL dump restored into temporary database `niks3_restore_probe`. The restored database contained eight public tables. The probe then dropped the temporary database and removed its temporary file.

## Kache and CI recovery

All three Kache daemons are systemd-owned processes with parent PID 1. `ExecStartPre` stops a competing user daemon before systemd claims the run lock.

Radicle CI sync now requests one admitted preferred seed with a 30-second fetch timeout. It completed a preferred-seed fetch. The isolated runner completed with `runner_result=idle` after its executable, config, glibc, and compiler runtime were bound into the private store namespace.

Radicle sync now runs every 15 minutes instead of every minute. Buildbot master and worker are active.

## Final health

After the final coordinated RustFS restart, six consecutive samples returned HTTP 200 for all ten checked endpoints. Kache, RustFS, isolated RustFS, niks3, lab Celld, Site Celld, Prometheus, Radicle CI, and Buildbot units were active or successfully idle as designed.

## Non-claims

- The evidence does not prove raw distributed RustFS volume restoration.
- The object snapshot is BLAKE3-bound but is not a transactionally atomic S3 snapshot.
- The existing large queues are preserved, not fully drained.
- Automatic Nix uploads remain disabled until a later change proves long-duration coordination availability.
- RustFS distributed mode remains experimental.
- Resource weights reduce contention but do not prove a fixed bandwidth ceiling.
