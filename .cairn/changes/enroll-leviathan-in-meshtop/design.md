# Leviathan Meshtop enrollment design

## Selected ownership and source

Leviathan is `leviathan.cymric-daggertooth.ts.net`, reachable by strict, noninteractive SSH as `brittonr`. It is not an onix-core inventory machine, so adding a machine-level Meshtop NixOS option or switching its whole system would misstate ownership. The same published Meshtop source commit pinned by onix-core, `42f908b2e4d470c7ba45efaab8cb8a75bddb4292`, was cloned on Leviathan and built there with locked Cargo dependencies and a GCC linker. Importing the desktop's unsigned Nix closure into Leviathan's untrusted user store was rejected; do not bypass the host's Nix trust policy. The compiled binary resides under the user's `~/.local/bin/`.

The onix-core `inventory/home-profiles/brittonr/meshtop/leviathan-agent.service` is the selected user-unit template on Leviathan. It starts only the read-only Meshtop agent, accepts the preexisting desktop viewer public ID and keeps Leviathan's newly created key at `~/.local/state/meshtop/agent.key` under systemd's private 0700 state directory. The key is 0600 and is never copied, evaluated into Nix, or committed. The observed new endpoint ID is `0cc38af96ba5edcac062ed2f0f90dcf2581915154a36b37a1b41677d87a304ac`.

## Viewer selection and runtime limit

The desktop Home Manager Meshtop profile appends that public ID as the fourth `leviathan` entry. The exact rendered roster is `/nix/store/wdca2qz37gin8cprz2cfk4gxz6xx2z4k-hm_.configmeshtophosts.toml`, retained by the existing `onix-roster` GC root and selected by the existing hosts-file link. The original three IDs, desktop viewer key, local desktop agent key, and existing agent units remain unchanged. A single authorized viewer received four live snapshots and paged to Leviathan's `AMD EPYC 7763 64-Core Processor` card. Its GPU counters were unavailable; this does not prove absence of all accelerators.

Leviathan's user manager reports `Linger=no`. The `brittonr` session cannot enable linger (`Access denied`), has no noninteractive sudo, and cannot SSH as root. Other current user sessions kept the enabled service running for the four-host sample. Only a Leviathan administrator can enable lingering for `brittonr` and then establish the service's logout/boot continuity; a service that merely starts during a user login does not prove that. No full system switch or reboot was performed.

The operator explicitly accepted session-only availability for this
enrollment. Enabling linger is not a pending step of this change; it requires
separate administrator action before anyone can claim boot or logout
continuity.

## Maintenance and rollback

onix-core maintains the viewer roster, its GC root/link, the exact source pin, the selected service template and the operator instructions. Leviathan's administrator maintains the local source build and user-manager lifecycle. A later onix-core source pin requires a new Leviathan local binary build before claiming uniform source revision. To undo the enrollment, remove only Leviathan's public ID from the managed roster and regenerate its GC-rooted hosts file, then disable/stop only Leviathan's user unit. Retain the existing three identities and do not delete or rotate any key without separate authority. No aliases, network port forwarding, or alternate viewer identity are needed.
