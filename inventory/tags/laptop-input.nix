{ lib, ... }:
{
  # Kanata for system-wide keyboard remapping
  # CapsLock = Esc on tap, Ctrl on hold (with nav layer via hjkl)
  services.kanata = {
    enable = lib.mkDefault true;
    keyboards.default = {
      devices = [ ]; # all keyboards
      extraDefCfg = "process-unmapped-keys yes";
      config = ''
        (defsrc
          caps h j k l u d w b 0 4
        )

        (defvar
          tap-timeout 200
          hold-timeout 200
        )

        (defalias
          ;; CapsLock: tap = Esc, hold = Nav layer (inherits Ctrl behavior)
          cap (tap-hold-press $tap-timeout $hold-timeout esc (layer-while-held nav))
        )

        ;; Base layer - only CapsLock is remapped, everything else passes through
        (deflayer base
          @cap _ _ _ _ _ _ _ _ _ _
        )

        ;; Nav layer - vim-style navigation available system-wide
        ;; Hold CapsLock + hjkl for arrows, u/d for page up/down, etc.
        (deflayer nav
          @cap left down up rght pgup pgdn C-rght C-left home end
        )
      '';
    };
  };
}
