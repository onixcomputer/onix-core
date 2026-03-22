## ADDED Requirements

### Requirement: sudo-rs replaces C sudo
All NixOS machines SHALL use `security.sudo-rs` as the sudo implementation. The C sudo package SHALL be disabled.

#### Scenario: sudo binary is sudo-rs
- **WHEN** a user runs `sudo --version` on any NixOS machine
- **THEN** the output identifies sudo-rs, not the traditional C sudo

#### Scenario: C sudo is not active
- **WHEN** `security.sudo-rs.enable` is true
- **THEN** `security.sudo.enable` is false (the NixOS module handles this automatically)

### Requirement: execWheelOnly policy is preserved
The `execWheelOnly` restriction SHALL be maintained. Only root and wheel group members SHALL be able to execute sudo.

#### Scenario: execWheelOnly on standard machines
- **WHEN** a NixOS machine uses the default `nixos` tag config
- **THEN** `security.sudo-rs.execWheelOnly` is true

#### Scenario: execWheelOnly override on britton-desktop
- **WHEN** britton-desktop's configuration is evaluated
- **THEN** `security.sudo-rs.execWheelOnly` is `lib.mkForce false` (to allow per-user extraRules)

### Requirement: extraRules migrate to sudo-rs
britton-desktop's per-user NOPASSWD rules for bpftrace and chaoscontrol-trace SHALL work under sudo-rs using `security.sudo-rs.extraRules`.

#### Scenario: NOPASSWD bpftrace
- **WHEN** brittonr runs `sudo bpftrace` on britton-desktop
- **THEN** no password is prompted (NOPASSWD rule active)

#### Scenario: NOPASSWD chaoscontrol-trace
- **WHEN** brittonr runs `sudo /home/brittonr/.cargo-target/release/chaoscontrol-trace` on britton-desktop
- **THEN** no password is prompted (NOPASSWD rule active)

### Requirement: PAM configuration is preserved
PAM settings for sudo (e.g., fprintAuth disabled on britton-desktop) SHALL continue to work with sudo-rs.

#### Scenario: fprintAuth disabled for sudo on britton-desktop
- **WHEN** britton-desktop's PAM configuration is evaluated
- **THEN** `pam.services.sudo-rs.fprintAuth` is false (or equivalent PAM service name used by sudo-rs)

### Requirement: Darwin machines are unaffected
sudo-rs SHALL NOT be enabled on darwin machines. macOS machines SHALL continue using the system sudo.

#### Scenario: britton-air unchanged
- **WHEN** the `nixos` tag config is evaluated for britton-air (darwin)
- **THEN** no sudo-rs configuration is applied
