🚧🚧🚧 Under construction! Not for use *yet*™ 🚧🚧🚧

# Onix Infrastructure

## Development

Run `nix develop --accept-flake-config --no-pure-eval` to open the default devenv.sh shell.

If you use direnv, run `direnv allow` once. The `.envrc` file opens the same shell automatically.

Read [`docs/dgx-machines.md`](docs/dgx-machines.md) for the device-free DGX machine lifecycle.

Read [`docs/bookshelf.md`](docs/bookshelf.md) for the private ebook library endpoint, publishing procedure, and backup boundary.

## References
- [BlinkDL/RWKV-LM](https://github.com/BlinkDL/RWKV-LM) — pinned official RWKV-7 model, byte-tokenizer, and PyTorch recurrence equations used by the real-weight, stateful-decode, bounded-prompt, and CPU equation-reference harnesses.
- [fla-org/flash-linear-attention](https://github.com/fla-org/flash-linear-attention) — pinned v0.3.0 checkpoint naming, cross-layer value mixing, recurrent cache, model normalization, and untied language-model head wiring used to decode and independently compare the Hugging Face model format.
- [denoland/celld](https://github.com/denoland/celld) — pinned self-hosted Durable Objects runtime used by the private RustFS-backed Celld fleet.
- [devenv](https://github.com/cachix/devenv) — developer environment framework used by the default flake shell.
- [Grafana](https://github.com/grafana/grafana) — upstream Grafana 13.0.3 generated email assets retained to repair the package's missing runtime templates.
- `../herdr-plugin-pueue` — local Herdr Pueue dashboard source vendored for the plugin wrapper until the repository has a remote.
- [ki-editor/ki-editor](https://github.com/ki-editor/ki-editor) — upstream flake used for the Ki editor package.
- [kunobi-ninja/kache](https://github.com/kunobi-ninja/kache) — upstream Rust/C/C++ build cache used for the desktop kache pilot.
- [kyuz0/amd-strix-halo-vllm-toolboxes](https://github.com/kyuz0/amd-strix-halo-vllm-toolboxes) — upstream Strix Halo RDMA/vLLM toolbox guide used for the `rdma-cluster` tag.
- [marty1885/ttWKV7](https://github.com/marty1885/ttWKV7) — upstream standalone RWKV-7 WKV7 operator packaged with its runtime JIT kernels.
- [murerkinn/bookshelf](https://github.com/murerkinn/bookshelf) — pinned self-hosted browser and OPDS library used by the private Tailnet Bookshelf service.
- [MercuryTechnologies/mercury-cli](https://github.com/MercuryTechnologies/mercury-cli) — upstream flake used for the Mercury terminal banking CLI.
- [Mic92/fast-nix-gc](https://github.com/Mic92/fast-nix-gc) — upstream fast Nix store garbage collector and optimiser used by store maintenance.
- [NathanFlurry/herdr-plugin-jj-workspace](https://github.com/NathanFlurry/herdr-plugin-jj-workspace) — Herdr plugin used for Jujutsu workspace actions.
- [nikok6/herdr-mirror](https://github.com/nikok6/herdr-mirror) — pinned Herdr plugin used to mirror remote Herdr workspaces.
- [Noelo-Lab/kuna](https://github.com/Noelo-Lab/kuna) — provides the binaries and SLEIGH specs for the Kuna decompiler package.
- [OnixResearch/tenstorrent.nix](https://github.com/OnixResearch/tenstorrent.nix) — dedicated flake owning Onix's Tenstorrent Blackhole packages, ttWKV7/RWKV harnesses, and retained evidence validators.
- [osolmaz/ghzinga](https://github.com/osolmaz/ghzinga) — pinned Rust CLI and Herdr link handler used for GitHub issue and pull request views.
- [paulbkim-dev/vim-herdr-navigation](https://github.com/paulbkim-dev/vim-herdr-navigation) — pinned Herdr and Neovim adapters used for pane navigation.
- [persiyanov/herdr-reviewr](https://github.com/persiyanov/herdr-reviewr) — pinned Herdr review sidebar plugin.
- [PrimeIntellect-ai/prime-agent](https://github.com/PrimeIntellect-ai/prime-agent) — upstream coding and research agent packaged for the development workstation.
- [RossComputerGuy/tenstorrent.nix](https://github.com/RossComputerGuy/tenstorrent.nix) — original upstream package history retained as the base of the OnixResearch repository.
- [smarzban/herdr-file-viewer](https://github.com/smarzban/herdr-file-viewer) — pinned Herdr file viewer plugin.
- [RWKV/RWKV7-Goose-World2.8-0.1B-HF](https://huggingface.co/RWKV/RWKV7-Goose-World2.8-0.1B-HF) — pinned Apache-2.0 BF16 checkpoint, delegator, and tokenizer/model/generation metadata used by the device-free real-weight, stateful-decode, fixed-text, bounded-prompt, and CPU equation-reference harnesses.
- [Tenstorrent software install docs](https://docs.tenstorrent.com/getting-started/README.html) — official driver, firmware, hugepages, and verification workflow mirrored by the `tenstorrent` host tag.
- [Tenstorrent software stack overview](https://docs.tenstorrent.com/software/index.html) — entry-point map for TT-Forge, TT-NN, TT-Lang, TT-MLIR, TT-Metalium, and cloud-native support mirrored in host docs.
- [tenstorrent/tt-inference-server](https://github.com/tenstorrent/tt-inference-server) — recommended model-serving workflow and model-support matrix for Tenstorrent hardware.
- [tenstorrent/tt-kmd](https://github.com/tenstorrent/tt-kmd) — official Tenstorrent kernel-mode driver flake used for NixOS KMD integration.
- [tenstorrent/tt-system-tools](https://github.com/tenstorrent/tt-system-tools) — upstream hugepages setup behavior adapted declaratively for NixOS.
- [tenstorrent/tt-system-firmware](https://github.com/tenstorrent/tt-system-firmware) — firmware bundle source packaged for manual `tt-flash` use.
- `../changebot` — sibling Remora Rust workspace used as the kache Nix-build pilot example.
- [graham33/nixos-dgx-spark](https://github.com/graham33/nixos-dgx-spark) — upstream NixOS hardware module used by the reusable `dgx-spark` machine tag.
- [cachix/devenv#3073](https://github.com/cachix/devenv/pull/3073) — experimental Devenv machines interface selected for the device-free DGX lifecycle plan.
- `docs/dgx-spark-power-profile.md` — DGX Spark GPU clock-cap serving profile, runbook, and measured power data.
- [OpenBubbles/openbubbles-app](https://github.com/OpenBubbles/openbubbles-app) — upstream serverless iMessage/Apple-services client; the pinned Linux release bundle wrapped as the local `openbubbles` package.
- [cachix/secretspec](https://github.com/cachix/secretspec) — declarative secret resolver used by the DGX installation bootstrap boundary.
- [Mesh-LLM/mesh-llm](https://github.com/Mesh-LLM/mesh-llm) — private inference mesh patched to read invite tokens from credential files.
- [Hister installing docs](https://hister.org/docs/installing) — upstream installing documentation for the Hister self-hosted search server and terminal client, covering prebuilt binaries, builds from source, Docker, Nix package and flake modules, and Proxmox installs.

