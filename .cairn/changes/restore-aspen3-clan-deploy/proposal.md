## Why

`clan machines update aspen3` could not deploy the current tree. Evaluation stopped on imported files that Git did not track and on a Grafana manifest that named an older release. Clan then evaluated on `root@britton-desktop`, which cannot fetch octet's GitHub-SSH cargo dependency. Units attached under `/etc/systemd/system.control` and hand-installed Underclass files on aspen3 would also have shadowed the units and links of the new generation.

## What Changes

- aspen3 builds as `brittonr@britton-desktop`.
- The Grafana email-template manifest names Grafana 13.1.6. The vendored template bytes are unchanged.
- aspen3 uses the desktop Underclass pool through its SSH tunnel instead of a second local pool.
- The attached laya and mesh-llm units, the tunnel unit and the OMP extension on aspen3 were moved to backups before the switch.

## Impact

- **Files**: `inventory/core/machines.ncl`, `modules/grafana/email-templates/manifest.{json,ncl,blake3}`, `modules/llm-agents/underclass.nix`, `modules/llm-agents/schema.ncl`, `inventory/services/services.ncl`.
- **Testing**: the aspen3 toplevel build, the `grafana-email-templates` check, `clan vars check` for aspen3 and britton-desktop, the Clan deployment, and runtime checks on aspen3.
