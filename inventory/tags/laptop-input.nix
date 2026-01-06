{ lib, ... }:
{
  # Keyd for dual-function keys (Caps Lock = Esc on tap, Ctrl on hold)
  # Useful for vim-style editing without remapping at compositor level
  services.keyd = {
    enable = lib.mkDefault true;
    keyboards = {
      default = {
        ids = [ "*" ];
        settings = {
          main = {
            capslock = "overload(control, esc)";
          };
        };
      };
    };
  };
}
