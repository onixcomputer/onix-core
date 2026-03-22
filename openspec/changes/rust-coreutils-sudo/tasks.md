## 1. Create rust-replacements tag config

- [ ] 1.1 Create `inventory/tags/common/uutils-sudo-rs.nix` with uutils-coreutils-noprefix in `environment.systemPackages` and `security.sudo-rs.enable = true` + `security.sudo-rs.execWheelOnly = true`
- [ ] 1.2 Import `./common/uutils-sudo-rs.nix` in `inventory/tags/nixos.nix`

## 2. Migrate britton-desktop sudo config

- [ ] 2.1 Change `security.sudo.execWheelOnly = lib.mkForce false` to `security.sudo-rs.execWheelOnly = lib.mkForce false` in `machines/britton-desktop/configuration.nix`
- [ ] 2.2 Move `security.sudo.extraRules` to `security.sudo-rs.extraRules` in `machines/britton-desktop/configuration.nix`
- [ ] 2.3 Update `security.pam.services.sudo.fprintAuth` to `security.pam.services.sudo-rs.fprintAuth` (verify the PAM service name sudo-rs registers)

## 3. Build verification

- [ ] 3.1 Run `build britton-desktop` — confirm no evaluation errors from sudo-rs + srvos interaction
- [ ] 3.2 Run `build britton-fw` — confirm a laptop config builds clean
- [ ] 3.3 Run `build aspen1` — confirm a server config builds clean
- [ ] 3.4 Run `build pine` — confirm an aarch64 config builds clean

## 4. Deploy and smoke test

- [ ] 4.1 Deploy to britton-desktop (local console access for rollback): `clan machines update britton-desktop`
- [ ] 4.2 Verify `ls --version` shows uutils on britton-desktop
- [ ] 4.3 Verify `sudo --version` shows sudo-rs on britton-desktop
- [ ] 4.4 Verify `sudo bpftrace --version` works without password on britton-desktop
- [ ] 4.5 Deploy to one remote server (aspen2): `clan machines update aspen2`
- [ ] 4.6 Roll out to remaining machines
