## Context

The Noctalia Home Manager profile starts `swayidle` as a user service. Its current timeout chain dims the screen, powers monitors off through Niri, and finally invokes `systemctl suspend`. That is appropriate for ordinary interactive laptops, but it conflicts with `aspen3` acting as a remote Lemonade host: a long model download or initial 35B load can outlive the idle timeout without generating local input.

## Decisions

### 1. Make idle suspend optional in the Noctalia module

**Choice:** Add `onix.idle.suspend.enable`, defaulting to `true`, and append the `systemctl suspend` timeout only when the option is enabled.

**Rationale:** The shared laptop behavior remains unchanged by default, while machine-specific profiles can opt out without duplicating the entire `swayidle` command. Display dimming and DPMS remain active, so the panel still powers down during remote work.

### 2. Disable only `aspen3` idle suspend

**Choice:** Set `home-manager.users.brittonr.onix.idle.suspend.enable = false` in `machines/aspen3/configuration.nix`.

**Rationale:** `aspen3` is the host observed dropping during a model pull. Other laptops should retain their existing automatic suspend behavior unless they become remote service hosts too.

### 3. Ignore lid sleep only when externally powered or docked

**Choice:** Configure logind to ignore docked and external-power lid-close events on `aspen3` while leaving the plain battery `HandleLidSwitch` unset.

**Rationale:** When `aspen3` is plugged in as an inference box, closing the lid should not interrupt remote work. When running as a mobile laptop on battery, the default lid suspend behavior remains available.

## Risks

- If `aspen3` is left unplugged with the lid open, disabling idle suspend can drain the battery faster. The existing low-battery udev suspend rule still applies at the configured critical threshold.
- The first live fix still requires `aspen3` to be reachable for deployment; this change only updates the desired configuration.
