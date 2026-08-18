# britton-desktop Accelerator Inventory Delta

## ADDED Requirements

### Requirement: Machine accelerator tags reflect installed hardware

r[onix.britton_desktop.accelerators.inventory] The `britton-desktop` machine inventory and generated hardware facts MUST include the installed Tenstorrent devices, MUST NOT include NVIDIA configuration while no NVIDIA PCI device is installed, and MUST NOT apply an AMD compute profile whose architecture assumptions do not match the installed Granite Ridge display controller.

#### Scenario: Current accelerator inventory passes validation

- GIVEN two Blackhole cards and one Granite Ridge display controller are installed
- WHEN machine inventory checks are evaluated
- THEN the `tenstorrent` tag is present
- AND the `nvidia` tag is absent
- AND generated graphics/initrd facts include `amdgpu` without `nvidia`
- AND generated PCI facts include both Blackhole devices

#### Scenario: Stale NVIDIA inventory is rejected

- GIVEN the `nvidia` tag is reintroduced without installed NVIDIA hardware
- WHEN machine inventory checks are evaluated
- THEN the accelerator inventory check fails

### Requirement: Services do not require absent NVIDIA devices

r[onix.britton_desktop.accelerators.services] The generated `britton-desktop` configuration MUST NOT enable a service that requires NVIDIA device passthrough while the host has no NVIDIA GPU.

#### Scenario: NVIDIA-only Krea service is absent

- GIVEN the host inventory has no NVIDIA accelerator
- WHEN the NixOS systemd units are generated
- THEN `docker-sglang-diffusion-krea2-britton-desktop.service` is absent
- AND both P150-backed model services remain configured

### Requirement: Tenstorrent debugging guidance references official tools

r[onix.tenstorrent.debugging.tooling_reference] The generated Tenstorrent host guide MUST reference the official TT-Metalium tools index, MUST identify Inspector output and RPC as the first Metal runtime evidence, and MUST explain that `tt-triage`, Watcher, Device Print, and profilers may require a matching source build or checkout.

#### Scenario: Operator investigates a Metalium service failure

- GIVEN a P150-backed model service fails or hangs
- WHEN the operator reads `/etc/tenstorrent/README.md`
- THEN the guide directs them first to `tt-smi`, the service journal, and service-private Inspector logs
- AND it provides the official tools index for source-level escalation
