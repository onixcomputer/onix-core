## Context

Live `lspci -nn` output on `britton-desktop` reports:

- `01:00.0` Tenstorrent Blackhole `[1e52:b140]`
- `03:00.0` Tenstorrent Blackhole `[1e52:b140]`
- `7b:00.0` AMD Granite Ridge Radeon Graphics `[1002:13c0]`
- no NVIDIA display or accelerator device

The inventory nevertheless assigns the `nvidia` tag and configures `krea2-britton-desktop` with `gpuPassthrough = "nixos-nvidia"`. Its generated `machines/britton-desktop/facter.json` also records NVIDIA graphics, causing NixOS to require a nonexistent `nvidia` module in the initrd after the tag is removed. The generic `amd-gpu` tag is not a correct replacement: it contains Strix Halo `gfx1151` compute overrides and a large unified-memory TTM budget that are inappropriate for this small Granite Ridge display controller.

The official TT-Metalium tools index is https://docs.tenstorrent.com/tt-metal/latest/tt-metalium/tools/index.html. It states that tools are only fully supported on source builds. Inspector is enabled by default, serializes data under `generated/inspector`, and exposes configurable loopback RPC. `tt-triage` consumes Inspector data from a Python 3.10+ source checkout. Watcher instruments kernels and is therefore an opt-in reproduction tool rather than a production default.

## Decisions

### Decision: Model only installed accelerator hardware

**Choice:** Keep the `tenstorrent` tag and remove the `nvidia` tag from `britton-desktop`.

**Rationale:** Machine tags are declarative hardware claims. Retaining a vendor tag for absent hardware creates invalid drivers, packages, environment variables, and service assumptions.

### Decision: Regenerate hardware facts instead of patching them

**Choice:** Run Clan's `nixos-facter` hardware update against the live host and commit its generated report.

**Rationale:** The report is generated hardware evidence. Regeneration removes NVIDIA from graphics/initrd facts and records both Blackhole cards without a fragile hand-edited JSON delta.

### Decision: Do not substitute the existing AMD compute tag

**Choice:** Rely on the normal amdgpu/Mesa graphics path for Granite Ridge and do not add the current `amd-gpu` tag.

**Rationale:** That tag is tuned for a different compute-capable integrated GPU (`gfx1151`). Applying it would replace one false hardware model with another.

### Decision: Remove the NVIDIA-only image service

**Choice:** Delete the `krea2-britton-desktop` service instance rather than changing passthrough to `none`.

**Rationale:** SGLang-Diffusion still requests one GPU and cannot provide the intended Krea service on this host without a supported accelerator backend. A permanently failing or misleading unit has no operational value.

### Decision: Keep production diagnostics lightweight

**Choice:** Keep per-service Inspector logging/RPC enabled through its upstream defaults and document the generated log locations. Use `tt-smi`, journals, and Inspector output first. Escalate to `tt-triage`, Watcher, Device Print, or profilers only in a matching source checkout reproduction.

**Rationale:** The Nix package contains the runtime but does not install the complete `tools/tt-triage.py` source workflow. Watcher and kernel instrumentation can alter timing and binary size, so they should not be enabled on healthy production services.

## Risks / Trade-offs

- Removing the NVIDIA tag changes the graphics closure; the full NixOS generation and live Niri session must be validated before acceptance.
- Krea image generation becomes explicitly unavailable on this host instead of remaining configured but unusable.
- Historical CUDA benchmark evidence remains historical; it must not be interpreted as currently available hardware.
- Some TT-Metalium debugging tools require a source checkout matching the pinned runtime version.
