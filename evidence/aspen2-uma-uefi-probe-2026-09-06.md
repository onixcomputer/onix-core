# Aspen2 native UMA probe

## Result

The read-only UEFI probe passed on Aspen2 BIOS 03.03.
Aspen2 returned to its existing NixOS system after the probe.
The native AMD protocol reported Auto / High under purpose 3.
No UMA configuration value changed. VRAM remains 64 GiB.
The write-capable stage is not implemented or admitted by this receipt.

The original GRUB configuration is restored byte-for-byte.
`Setup` and `AmdSetup` still match the corrected pre-probe backups byte-for-byte.
SSH is active. Qwen and mesh remain inactive.
The probe continuation used one-boot systemd masks to prevent their known startup errors.
Those masks do not change the source configuration or later normal boot entries.

## Artifact and validation

Source: `pkgs/aspen-uma-helper/`

The package pins r-efi 5.3.0 and Octet revision `f39ab155170f32ffc6408782d20c0d488137c995`.
Nix generated the nested `flake.lock`. The root lockfile did not change.

The deployed binary came from:

```text
/nix/store/8girvzfkh9yqkzlnln9ivhdyxik9x640-aspen-uma-helper-uefi/bin/uma-probe.efi
```

Its BLAKE3 is:

```text
2ec5d02f60b5a7e1110315c2c65619a23c8c6ab39dd8c45da3e41eda4dc78697
```

The package passed:

- Nineteen positive and negative Rust tests.
- Strict Clippy for the host workspace and the UEFI binary.
- The official pinned Octet hook with workspace, all-target, and all-feature scope.
- The full pinned Octet catalog with zero findings, warnings, or errors.
- All nested Nix checks.
- Three OVMF cases: valid probe with no AMD protocol, malformed image, and stale report.

Each OVMF case returned to its parent GRUB script.
The malformed image produced no report. The stale-report case preserved the previous report.
These VM cases do not prove native AMD write permission.

Commands ran from the helper directory:

```sh
nix run path:.#octet-deny-all -- --workspace -- --all-targets --all-features
nix flake check -L path:.
nix build path:.#uma-probe --print-out-paths
```

The initial empty Rust scaffold compiled before the core implementation.
The tests then ran after each core repair.
The lint fixes retained the full catalog. Test modules use explicit `cfg(test)` scope.
Narrow source exceptions retain the real unsafe obligations at the firmware ABI.

## Live evidence

The one-shot GRUB selector cleared before the EFI application ran.
The entry continued into the existing kernel and initrd after the application returned.
Secure Boot was disabled. The uploaded image passed its BLAKE3 check before the reboot.

The live report contains:

```text
aspen-uma-probe/v1
firmware_updates=disabled
started=true
apcb.locate=0x0
apcb.revision_word=3
oem=UmaSnapshot { mode: 2, level: 2, custom_mib: 512 }
amd=UmaSnapshot { mode: 2, level: 2, custom_mib: 4294967295 }
apcb.mode=Ok(TokenSample { purpose: 3, value: 2 })
apcb.level=Ok(TokenSample { purpose: 3, value: 2 })
verdict=HighObserved
observation.status=0x0
completed=true
```

Before the probe, the boot ID was `8f46660a-ec4b-4ea1-a6ec-64308c445297`.
After the probe, it was `2d81e047-d388-4d5c-999e-6ce2f6c78f24`.
Linux reported `68719476736` VRAM bytes and `65617512` kB of total memory.
Both model and mesh services were inactive with zero restarts in the new boot.

The retained remote paths are:

- `/boot/EFI/OnixUMA/probe.efi`
- `/boot/EFI/OnixUMA/probe.log`
- `/root/uma-uefi-probe-20260906/`
- `/root/uma-backup-read-20260906/`

No boot entry selects the probe after cleanup.

## Firmware ABI evidence

Two independent read-only audits examined the APCB ABI and the alternative native HII route.
The original vendor typedef for the revision field remains unavailable.
The implementation instead validates the complete observed x64 header word, with a binary layout test.

The Get8 method is at offset `0x98`.
It takes a protocol pointer, an output purpose pointer, a 32-bit token UID, and an output byte pointer.
Both output pointers must remain valid, including on the SMM path.
The automatic-level token is `0xe3ab8ca4`. The mode token is `0x1fb35295`.

Offset `0xd8` is not a harmless selector. It erases token data in the selected purpose.
The read-only interface exposes none of the erase, setter, lock, or flush methods.
The getter can change RAM selection state. This receipt does not claim an absence of all effects.

Further static analysis identified the SMM message handler at RVA `0x33b8`.
It routes command `0xa1cb0007` to getter `0x25c8`, then copies the result to the caller.
The getter performs token lookup. Its error path can deny access without a write.
The earlier tentative address `0x3390` is a different method and is not the message handler.

The HII alternative remains blocked on browser initialization and callback semantics.
Its save route also ignores some native write results, so a successful RouteConfig return is not completion evidence.

## Bounds and remaining work

The initial implementation round had a sixty-minute bound.
A further thirty-minute validation round covered the fixture repairs and the live read-only boot.
An unrelated workstation link error removed tools from PATH during validation.
Process-local store paths restored access without changing that workstation link.
Some Pueue task history disappeared during concurrent work. The files below retain the evidence.

The native read route is validated. The native write route is not.
A later stage needs explicit identity admission, transaction and rollback tests, and verified handling of setter, variable-write, flush, and unlock errors.
It also needs a recovery procedure for a host that cannot POST.
No read result or backup establishes that recovery procedure.

This receipt does not claim 512 MiB of VRAM, successful text or vision inference, or working mesh routing.

Detailed local artifacts are under:

`~/.local/state/onix/deployments/aspen2-20260906/uma-uefi/`

The key files are `contract.md`, `abi-audit.log`, `native-route-audit.log`, `octet-final.log`, `flake-check.log`, `live-probe.log`, `live-result.log`, and `restore-and-compare.log`.
