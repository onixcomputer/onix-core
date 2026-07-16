## Context

The archived measurement at commit `04b3cae6` retained invocation count zero because `sudo -n true` required authentication before the device-1 owner could be stopped. `sudo -n -l` showed only two unrelated passwordless commands. Strict loopback root SSH with the pinned host fingerprint and `~/.ssh/framework` succeeds, but exposing a general root channel inside every diagnostic runbook is broader than the required operation and does not express the capability in the NixOS configuration.

The exact privileged operations are stable: stop and later start `docker-tt-inference-server-llama-3-1-8b-instruct-p150.service`, and inspect open files for `/dev/tenstorrent/1`. Status, container, endpoint, board-health, runtime preflight, and the probe itself remain unprivileged.

## Success Contract

The change succeeds when the evaluated `britton-desktop` configuration contains passwordless permission for only the exact owner-unit start/stop and exact device ownership inspection commands, installs one immutable wrapper that can validate those permissions and fail closed around isolation, and rejects unsupported modes and overbroad capability shapes without executing privileged operations during build checks.

False completion includes `NOPASSWD: ALL`, a systemctl command without fixed arguments, wildcard units or devices, `restart`, permissions for another service, relying on cached interactive credentials, root SSH inside the normal runbook, or treating owner control as hardware authorization.

## Decisions

### Decision: Use argument-exact sudoers entries

**Choice:** Extend the existing machine-local `security.sudo.extraRules` for `brittonr` with three fixed commands: systemd `stop` of the exact owner unit, systemd `start` of the exact owner unit, and `lsof` of the exact device path.

**Rationale:** This host already carries reviewed per-user passwordless exceptions and disables the srvos root/wheel-only assertion for them. Sudoers command arguments are part of the match, so fixed store paths and fixed arguments expose less authority than wildcard systemctl or a general root SSH channel.

### Decision: Put lifecycle policy in an immutable wrapper

**Choice:** Install `ttwkv7-owner-control` with `validate`, `isolate`, and `restore` modes. `validate` asks sudo whether each exact command is allowed. `isolate` requires the owner active, stops it once, proves it inactive, and checks the exact device for open owners; an exit trap restarts the owner if isolation validation fails. `restore` starts the exact unit and proves it active.

**Rationale:** Future reviewed runbooks call one stable interface instead of reproducing privilege syntax. The wrapper contains no package path, probe command, runtime-state argument, device selection override, retry, or compatibility claim.

### Decision: Keep pure capability validation separate from execution

**Choice:** Represent the required and rejected command shapes as deterministic Nix values evaluated by the machine check. Keep systemctl, sudo, and lsof calls in the thin wrapper shell.

**Rationale:** Security shape can be tested without root, service mutation, mocks, or hardware. The shell remains explicit orchestration with fixed inputs.

## Approach Registry

| Family | Mechanism | Evidence | Gap | State |
|---|---|---|---|---|
| Exact sudoers | Match fixed executable plus fixed verb/unit or device argument | Existing machine-local sudo rules and NixOS structured configuration | Requires one normal host activation before use | active |
| Unit Polkit | Permit start/stop for one unit through `manage-units` details | Installed policy supports authenticated unit management | Still needs a separate privileged lsof mechanism and custom policy testing | blocked |
| Root SSH | Use strict fingerprint-pinned loopback root commands | No-op root SSH with explicit framework key passed | Exposes a general root channel to each runbook | audit |
| Interactive sudo | Prime a credential cache before execution | General sudo currently requires authentication | Non-interactive/TTY cache coupling is not reproducible | falsified |
| Root probe broker | Run the whole probe in one root-owned service | Could provide transactional ownership | Couples every reviewed package/runtime path to host activation | blocked |

## Adversarial Audit

The evaluated checks must inspect both positive and negative sets. Presence of the three required commands is insufficient if another rule grants wildcard systemctl, `ALL`, arbitrary lsof, restart, or another unit. The wrapper's invalid and extra-argument paths must return before sudo. Isolation must arm restoration before issuing stop, and successful isolation must deliberately transfer restoration responsibility to the caller. A caller can still invoke the exact raw permitted commands, so this capability intentionally grants availability control over this one inference endpoint; it grants no broader root shell or device execution authority.

A NixOS activation is required before runtime `validate` can pass. This implementation and its checks do not activate the generation, stop the service, inspect the physical device, or consume hardware authorization.

## Risks / Trade-offs

- `brittonr` can stop this one inference service outside a probe run; that is the explicit capability being granted.
- Sudo command matching depends on fixed executable and argument strings, so the wrapper and rules must be generated from the same constants.
- A generation change updates store paths atomically through the same configuration, avoiding stale manually edited sudoers paths.
- The wrapper cannot guarantee restoration if a caller successfully isolates and then never installs its own trap; reviewed probe runbooks remain responsible for calling `restore` from an exit trap.

## Validation Plan

1. Establish passing accelerator-inventory and complete host-closure baselines.
2. Gate the Cairn proposal, design, tasks, and delta requirement.
3. Evaluate the exact required command set and prove rejected broad command shapes are absent.
4. Build and run no-privilege wrapper usage and invalid-mode checks.
5. Rebuild the accelerator inventory and complete `britton-desktop` closure.
6. Run formatting, `git diff --check`, final Cairn validation, sync, and archive.

## Validation Evidence

The pre-change accelerator inventory and complete `britton-desktop` closure passed. The implemented inventory check then passed positive exact-command checks and negative wildcard, unrelated-unit/device, `ALL`, invalid-mode, extra-argument, device-selection, and probe-invocation checks. It also inspected grants inherited through the user's groups so a future passwordless wheel wildcard cannot bypass the negative policy.

The rendered sudoers output contains exactly three new entries: fixed-store-path systemctl `stop` and `start` commands for `docker-tt-inference-server-llama-3-1-8b-instruct-p150.service`, plus fixed-store-path lsof for `/dev/tenstorrent/1`. The immutable wrapper passed ShellCheck through `writeShellApplication`, positive `--help`, negative invalid-mode and extra-argument checks, and static lifecycle/target inspection. The final accelerator inventory and complete host closure passed; only pre-existing expired cached tree-sitter reference warnings were emitted. No generation was activated, no service state changed, no Tenstorrent device was accessed, and no hardware authorization was consumed.
