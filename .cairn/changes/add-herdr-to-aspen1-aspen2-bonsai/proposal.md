# Add Herdr to Aspen1, Aspen2, and Bonsai

## Why

Aspen3 and britton-desktop already provide the wrapped Herdr package and the managed brittonr profile. Aspen1, Aspen2, and Bonsai should expose the same terminal workflow after their next managed activation.

## What Changes

- Add the existing wrapped `self.packages.${system}.herdr` to each requested machine's system packages.
- Expand the existing explicit Herdr Home Manager assignment to Aspen1, Aspen2, Aspen3, and Bonsai, retaining the desktop assignment.
- Reuse the typed config, immutable plugin bundle, and Neovim adapter without adding package sources or activation side effects.

## Impact

- **Scope**: Three machine configurations and the shared user inventory.
- **Rollout**: Declarative configuration only; no remote deployment or running-session restart.
- **Verification**: Evaluate the selected packages and generated Home Manager files for every target, run the wrapped Herdr against the generated config, and validate Cairn artifacts.
