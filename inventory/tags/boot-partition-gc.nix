{ lib, ... }:
{
  # Keep small EFI /boot partitions from accumulating unbounded GRUB entries.
  boot.loader.grub.configurationLimit = lib.mkForce 5;

  # Prune old system profile generations before store GC so deleted boot
  # generations can actually become collectable.
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkForce "--delete-older-than 14d";
  };
}
