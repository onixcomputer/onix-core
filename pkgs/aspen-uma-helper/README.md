# Aspen UMA helper

This package contains a read-only UEFI probe for Framework Desktop BIOS 03.03.
It cannot change UMA configuration. It contains no APCB setter, erase method, lock call, flush call, or EFI variable write.
The probe writes only its own report at `\EFI\OnixUMA\probe.log` on the image filesystem.
It rejects an existing report rather than overwrite evidence from an earlier boot.

## Scope

The probe locates AMD APCB protocol `7189E04E-6284-4953-A543-A31F89A1A7BF`.
It reads the observed revision word and the matching OEM and AMD variable payloads.
It then calls the native Get8 method for the UMA mode and automatic level.
An error remains an error. A successful zero value remains a value, not an absent token.
The report records observations, not permission for a later update.

The getter can change RAM selection state and use SMM communication.
Read-only here means no persistent firmware configuration update, not an absence of all effects.
The intended context is a single UEFI application before `ExitBootServices`, without a concurrent APCB caller.
This package does not claim support for other BIOS revisions or an independent recovery path after failed POST.

## Verification

The pure domain module decodes and assesses explicit values.
The UEFI adapter owns protocol calls and filesystem access.
The entry module owns panic recovery through the parent loader.
Narrow unsafe-boundary exceptions retain the raw-pointer obligations at the firmware ABI.

The Nix input pins Octet at `f39ab155170f32ffc6408782d20c0d488137c995`.
The full pinned catalog runs as an error gate. There is no finding baseline or disabled lint.
The official hook uses workspace, all-target, and all-feature scope.

From this directory:

```sh
nix develop path:. --command cargo test --workspace --all-targets --all-features
nix run path:.#octet-deny-all -- --workspace -- --all-targets --all-features
nix flake check -L path:.
nix build path:.#uma-probe --print-out-paths
```

The host matrix covers the full workspace and all test targets.
The UEFI matrix builds the binary and runs Clippy for that target.
The OVMF checks cover a valid probe with no AMD protocol, a malformed image, and a stale report.
Each VM case must return to the parent GRUB script.
These checks do not establish live firmware permission or a successful UMA update.

## Boot procedure constraints

CAUTION: Preserve the normal boot entry. An unverified UEFI image can stop the current boot.

Before a live probe, verify the BIOS identity, image hash, and Secure Boot state.
Verify the original GRUB configuration.
The one-shot selector must clear itself before the image starts.
The probe directory must exist and the report must not exist.
The parent entry must continue into the known-good Linux image after the probe returns or fails to load.
The operator must retain the original configuration and restore it after the probe.
No raw variable or SPI fallback is part of this package.

## Third-party notice

This package uses r-efi under its MIT license option.
The unmodified `third-party/r-efi-AUTHORS` file retains its copyright and permission notices.
The Nix package installs that file beside the binary distribution.

## References

- [r-efi 5.3.0](https://crates.io/crates/r-efi/5.3.0): pinned UEFI ABI definitions. Its Cargo checksum retains registry integrity evidence.
- [Framework Desktop BIOS 3.03](https://resources.frame.work/downloads/desktop/amd-ryzen-ai-max-300/3.03/): the matching firmware source archive.
- [Octet](https://github.com/OnixResearch/octet/tree/f39ab155170f32ffc6408782d20c0d488137c995): the pinned lint catalog and official error hook.
