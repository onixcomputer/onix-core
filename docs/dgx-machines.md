# DGX machine lifecycle

This repository uses an experimental Devenv interface for DGX machines only. Clan continues to own all non-DGX machines.

The canary uses `cachix/devenv` commit `6e61f6a12f730b81228f70ee2487320fdbb1e2fc`. The normal development shell uses a separate Devenv input.

## Current boundary

The production DGX map is empty. The repository does not define a machine name, target, disk, hardware report, or host key.

The `dgx-machine` command has two operations:

```console
dgx-machine info
dgx-machine build <name>
```

The `info` operation reads Devenv machine metadata. The `build` operation builds `machines.<name>` without target access.

The command rejects `install`, `deploy`, unknown operations, and undeclared machine names. A separate authorized Cairn change must add live operations.

CAUTION: Do not invoke the experimental Devenv CLI directly for a DGX machine. Its install operation can erase the declared disks.

## Machine data

Nickel owns the production machine map in `inventory/dgx/machines.ncl`. The generated input is `inventory/dgx/generated/machines.json`.

Each real machine needs these reviewed facts:

- a Devenv-safe machine name
- the `aarch64-linux` system
- a root SSH target
- a stable `/dev/disk/by-id/...` disk identity
- a machine-specific Disko module
- a committed facter report
- a strict `known_hosts` file and its SHA256 fingerprint
- the `framework-only` access policy
- SecretSpec names for each required runtime credential
- one Mesh-LLM backend owner
- the model alias that Mesh-LLM requests
- an optional hash-pinned local GGUF profile

Machine files use these paths:

```text
.machines/<name>/disko.nix
.machines/<name>/facter.json
.machines/<name>/known_hosts
```

Do not use a generic NVMe path, an example value, or a shared facter report.

## Safe validation

Export the typed machine data after a Nickel change:

```console
nickel export --format json inventory/dgx/machines.ncl > inventory/dgx/generated/machines.json
nix eval --builders "" --json .#lib.machines.names > inventory/dgx/generated/clan-machine-names.json
```

Build the device-free gates:

```console
nix build --builders "" .#checks.x86_64-linux.dgx-machine-inventory --no-link -L
nix build --builders "" .#checks.x86_64-linux.dgx-devenv-interface --no-link -L
nix build --builders "" .#checks.x86_64-linux.dgx-devenv-disko --no-link -L
nix build --builders "" .#checks.x86_64-linux.dgx-machine-command --no-link -L
```

These gates use synthetic data. They do not open SSH connections or activate a target.

## Secret policy

The experimental DGX Devenv project enables SecretSpec. A future authorized installation must declare every typed `DGX_*` name in `secretspec.toml`.

Devenv resolves those names only during installation. It writes private root-owned files under `/var/lib/onix-dgx-secrets` without placing values in Nix data or store paths.

The current command wrapper does not expose installation. With an empty production map, this change does not resolve or copy a secret.

The source-built Mesh-LLM `v0.72.2` package accepts `--join-file`. systemd passes only its private credential path, so the invite token never enters process arguments.

The package pins its patched llama.cpp runtime source. Its Nix build does not clone source during a build.

## Service policy

The shared DGX NixOS module provides these services and tools:

- OpenSSH
- Tailscale with a SecretSpec bootstrap auth key
- Sendme
- iroh-ssh with SecretSpec bootstrap key files
- Mesh-LLM bound to `tailscale0`
- the `graham33/nixos-dgx-spark` NixOS module for GB10 hardware and CUDA support
- a CUDA `llama.cpp` OpenAI-compatible backend on `127.0.0.1:13305`

The upstream DGX input supplies hardware, kernel, CUDA, and NVIDIA policy. This setup does not use its playbooks for model serving.

The default local model is `RWKV7-G1i-13.3B Q6_K`. Its repository revision and Hugging Face LFS SHA-256 are fixed in `modules/dgx-machine/rwkv7-profile.nix`.

A machine can replace the default through `meshBackend.localModel` in the typed Nickel inventory. A replacement needs a model alias, repository, commit, GGUF path, SHA-256, context size, GPU layer count, and runtime flags. The Mesh-LLM alias must match the selected model alias.

The shared `modules/llamacpp-server/mk-nixos-config.nix` core serves both the DGX backend and existing llama.cpp services. Other existing model instances remain available.

Mesh-LLM needs one declared loopback backend owner. The owner is the fixed local systemd unit or an explicit external owner, not both.

The module authorizes only the Framework SSH key for `brittonr` and `root`. It does not authorize the cproof.ai key or discovered builder keys.
