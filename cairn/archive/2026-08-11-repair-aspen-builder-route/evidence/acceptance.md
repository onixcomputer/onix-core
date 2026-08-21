# Aspen builder-route acceptance

Date: 2026-08-11

## Evaluated configuration

`britton-desktop` evaluated one remote builder:

```text
ssh-ng://root@aspen1.local x86_64-linux /run/secrets/vars/per-machine/britton-desktop/nix-builder-ssh/id_ed25519 16 20 nixos-test,big-parallel,kvm - -
```

The evaluated list did not contain `10.10.10.1`. The managed Aspen host-key entry included `aspen1.local`.

## Validation

These checks passed before deployment:

- `checks.x86_64-linux.builder-no-self`
- `checks.x86_64-linux.ssh-host-key-consistency`
- `nixosConfigurations.britton-desktop.config.system.build.toplevel`
- Targeted `nix fmt`
- Cairn validation and artifact gates

The invalid Nickel fixture with an empty `sshHost` failed as required.

## Deployment

The active generation became:

```text
/nix/store/bvqdak5c5yn2cw8y2rl317ak8imh04g4-nixos-system-britton-desktop-26.11.20260803.104240a
```

The pinned Clan CLI could not evaluate the repository's WASM configuration with its bundled Nix. The exact built closure was activated through the managed `root@britton-desktop.clan` SSH target. This change did not require secret updates.

## Physical remote-build proof

The first route probe reached `ssh-ng://root@aspen1.local` but rejected a malformed proof derivation whose bash input was absent.

The corrected uncached derivation passed with local builds disabled:

```text
building '/nix/store/prn1m596l3izyph5dbglf5sby2fmdpzz-aspen-route-proof-7a2d9aa4-v3.drv' on 'ssh-ng://root@aspen1.local'...
aspen-route-proof> remote-builder-host=localhost
copying path '/nix/store/69y5g6sdlkzcmiyj04dq4sh7g8d52b7h-aspen-route-proof-7a2d9aa4-v3' from 'ssh-ng://root@aspen1.local'...
```

The sandbox hostname is `localhost`. The Nix transport lines prove that Aspen executed the derivation and returned its output.

## Device ownership

System activation restarted the existing Tenstorrent services. Both services were stopped before later RWKV work.

Neither `/dev/tenstorrent/0` nor `/dev/tenstorrent/1` had a process owner after cleanup.
