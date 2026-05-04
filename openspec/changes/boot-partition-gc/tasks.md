## 1. GRUB Generation Limit

- [x] 1.1 Add `boot.loader.grub.configurationLimit = 5` to the appropriate tag in `inventory/tags/` (likely `all.nix` or a new tag for GRUB machines)
- [ ] 1.2 Verify the setting applies to all physical GRUB machines by building at least one (`build aspen1` or `build aspen2`)

## 2. System Profile Generation Pruning

- [x] 2.1 Update the nix-gc module or tag config to prune system profile generations older than 14 days before running store GC
- [x] 2.2 Verify the GC service unit includes `--delete-older-than 14d` or equivalent by inspecting the built config

## 3. Deploy and Validate

- [ ] 3.1 Deploy to aspen1 and aspen2 — confirm GRUB installs successfully with the generation limit active
- [ ] 3.2 Confirm `/boot` usage is bounded post-deploy (check `df -h /boot` and `ls /boot/kernels/` on at least one machine)
