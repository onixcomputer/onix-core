# Enroll SSH-reachable machines in Meshtop

## Why

The current authenticated desktop viewer pins only Aspen3 and britton-desktop. The operator needs every onix-core machine reachable over the configured SSH routes to appear in that monitor, without treating offline inventory entries as running agents.

## What Changes

- Check strict, noninteractive SSH access to every machine in the core inventory and record the selected reachable set and exclusions. The separate DGX inventory currently declares no machines.
- Keep Aspen3 and britton-desktop unchanged. Opt Bonsai into the existing NixOS Meshtop service, authorizing only the current desktop viewer ID and generating a distinct private agent key on Bonsai.
- Add Bonsai's observed public endpoint ID to the desktop Home Manager roster. Activate only the generated Bonsai system unit and updated desktop roster; do not switch unrelated whole-host generations.
- Verify all selected hosts through the paired viewer, including explicit failure status when a host is unreachable.

## Impact

- **Owners:** onix-core owns host selection, the NixOS service policy, roster, scoped activation, and follow-up adoption. The standalone Meshtop repository owns the unchanged collector, transport, and terminal renderer.
- **Boundaries:** SSH reachability authorizes an attempt to enroll a selected host, not a blanket shared-tag agent, SSH command authority from the viewer, or future availability. Each private agent identity remains on its own host and the viewer key remains only on the desktop. Targets that failed their configured or documented alternate SSH routes are not pinned as live agents. The initial Aspen3 and desktop runtime boundaries remain unchanged.
- **Verification:** Strict noninteractive SSH observations, isolated generated-unit build and activation, persistent key/public-ID checks, Home Manager roster output, authorized three-host samples and terminal navigation, and focused Cairn and repository checks. Scoped activation is not a whole-system or reboot-continuity claim.
