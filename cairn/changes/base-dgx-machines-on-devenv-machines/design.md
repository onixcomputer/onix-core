## Context

The repository uses Clan inventory for current NixOS machines. The new `dgx-spark` tag is reusable, but no machine has that tag.

The repository also uses Devenv for its development shell. Its locked Devenv revision is not the experimental machines pull-request head.

Pull request [cachix/devenv#3073](https://github.com/cachix/devenv/pull/3073) defines `machines.<name>` for NixOS, nix-darwin, and Home Manager systems. It adds `info`, `deploy`, and `install` commands.

The pull request evaluates a new NixOS system from each machine module. It does not deploy an existing Clan `nixosConfiguration` closure.

DGX machine names, target hosts, disk identities, facter reports, and SSH host keys are not available. This design does not create substitutes for them.

## Decisions

### 1. Use a separate exact canary pin

**Choice:** Add a `devenv-machines` input at commit `6e61f6a12f730b81228f70ee2487320fdbb1e2fc`. Keep the current `devenv` input for the development shell.

**Rationale:** The pull request is open and experimental. A separate pin prevents a DGX trial from changing the normal development shell.

The repository will expose the pinned command through one DGX-specific app. It will not put the experimental CLI in the default shell path.

A compatibility check will prove that the pin contains the expected NixOS machine options and commands. An input update must update that check in the same change.

### 2. Give each DGX machine one lifecycle owner

**Choice:** Devenv will own each declared DGX machine. Clan will not contain a machine record with the same name.

**Rationale:** Devenv evaluates a new NixOS system. Dual ownership can produce different closures and unsafe deployment choices.

A pure ownership function will compare the two machine-name sets. Evaluation will fail when the sets intersect.

The reusable Clan tag can remain for module checks and later rollback work. No active machine can use both lifecycle paths.

### 3. Keep machine data in typed Nickel

**Choice:** Add a typed Nickel map for DGX machine records. Export deterministic generated data for the experimental Devenv project.

Each real record will require these values:

- a real machine name
- `aarch64-linux` as the system
- a target host
- a stable `/dev/disk/by-id/...` disk path
- an SSH host-key fingerprint
- a committed facter report path
- the Framework SSH public key policy
- runtime secret names, without secret values
- ownership of the local OpenAI-compatible Mesh-LLM backend

The contract will reject empty values, placeholder values, `/dev/nvme*` paths, unsupported systems, and uncommitted facter paths.

**Rationale:** Nickel contracts catch invalid machine data before Nix evaluates it. Generated data avoids a dependency on Onix-specific Nix builtins inside the experimental CLI.

A freshness check will compare the generated data with a new Nickel export. The generated file is not an independent source.

### 4. Use one plain NixOS module graph

**Choice:** Export a plain `nixosModules.dgxMachine` module. Both the DGX tag checks and Devenv machines will consume this module graph.

The module graph will include these items:

- the pinned upstream `nixos-dgx-spark` module
- the `brittonr` account with UID `1555` and wheel access
- the Framework SSH key as the only key for `brittonr` and `root`
- OpenSSH, Tailscale, Sendme, iroh-ssh, and Mesh-LLM
- the existing dynamic `tailscale0` bind behavior for Mesh-LLM

A real record must name the local backend unit or declare an externally managed backend. The adapter will reject an unowned loopback backend.

The Tailscale, iroh-ssh, and Mesh-LLM modules will expose pure settings-to-Nix cores. Clan and Devenv shells will supply runtime files and service orchestration.

**Rationale:** A shared module graph prevents a Devenv copy from drifting from the tested DGX policy. The pure cores support direct evaluation checks.

### 5. Use Devenv SecretSpec bootstrap files

**Choice:** Typed `DGX_*` names will map to Devenv `install.secrets` entries. The experimental project enables SecretSpec, but this device-free change does not resolve values.

A future authorized installation will select the reviewed SecretSpec profile and provider. Devenv will atomically install root-owned runtime files under `/var/lib/onix-dgx-secrets`.

Mesh-LLM `v0.72.2` will use a source-built patch that adds `--join-file`. This keeps the credential change separate from an upstream version update. systemd will pass only its private credential path to the process.

The source build pins llama.cpp at `86b94708f22478f900b76ca02e316f4f3418faff`. Nix applies Mesh-LLM's patch series and builds the native runtime without a build-time network clone.

No secret value can enter Nickel, generated inventory data, Nix options, command arguments, logs, or the Nix store.

**Rationale:** The canary already keeps SecretSpec values outside Nix evaluation and machine metadata. A file-based Mesh-LLM interface preserves that boundary at runtime.

### 6. Expose device-free commands only

**Choice:** Add a repository-owned `dgx-machine` Rust command with `info` and `build` subcommands. The command will call the pinned Devenv CLI.

The command will reject `deploy`, `install`, unknown subcommands, and undeclared machine names. Argument parsing and policy decisions will form a pure core.

The process shell will only invoke the pinned CLI after the core accepts a device-free command.

**Rationale:** The upstream install command can repartition disks. This change does not have enough machine facts to make that command safe.

Direct use of the upstream CLI is unsupported. Documentation will show only the repository command.

### 7. Keep hardware and storage records explicit

**Choice:** Each future machine will use its own facter report and Disko layout. The storage record must name a stable disk identifier.

The implementation will not use the upstream sample disk name. It will not use a guessed UUID or a generic `/dev/nvme0n1` path.

A Disko evaluation check will prove that each declared disk identifier flows into the generated script. A negative fixture will reject an unstable disk path.

**Rationale:** The pull request's install path can erase storage. A machine-specific identity is a required safety fact.

### 8. Build before any future rollout

**Choice:** This change stops after `info` and device-free builds. It will build every declared DGX closure and Disko script without target access.

The first future installation cannot depend on the target as a builder. A later rollout plan must name a trusted `aarch64-linux` builder or prove local emulation capacity.

**Rationale:** The pull request can use machines as builders during deployment. That feature cannot bootstrap the first machine safely.

### 9. Move destructive work to a later Cairn change

**Choice:** A separate Cairn change must add install and deploy commands. That change requires real machine facts and operator authorization.

The later change must define these safeguards:

- a reviewed target and disk record
- strict SSH host-key matching
- Framework-key-only root access
- a backup acceptance record
- an installation stop point before final activation
- service health checks
- a rollback procedure

**Rationale:** Device-free integration and live machine mutation have different evidence and risk. Separate changes keep that boundary visible.

### 10. Define an upstream exit path

**Choice:** Keep the adapter small and isolate pull-request field names in one module. Do not spread the experimental interface across service modules.

If the pull request changes, update the adapter and compatibility fixtures. If the pull request is abandoned, remove the canary without rewriting DGX policy.

If Devenv releases a stable machines interface, replace the canary only after parity checks pass.

**Rationale:** DGX policy must not depend on the lifetime of one experimental branch.

## Risks and Trade-offs

- Two Devenv inputs increase lock-file size during the canary period.
- Generated inventory data adds a freshness check and a review step.
- Extracting plain NixOS cores changes service-module structure. Focused parity checks must cover current Clan behavior.
- The initial machine map can remain empty until real facts exist. Synthetic fixtures will cover the adapter during that period.
- Full DGX NixOS builds can use significant time and storage.

## Required Inputs for Real Machines

Implementation can add the framework with an empty production machine map. Real machine records require operator-provided facts.

The required facts include machine names, target hosts, disk identifiers, SSH host keys, facter reports, and Mesh-LLM backend ownership. The implementation must stop when any fact is absent.
