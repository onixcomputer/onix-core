{ lib, ... }:
{
  options.css = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      borderRadius = {
        sm = "0.5em";
        md = "0.6em";
        lg = "0.7em";
        px8 = "8px";
        px12 = "12px";
      };

      padding = {
        xs = "0.2em";
        sm = "0.3em";
        normal = "0.4em";
        md = "0.5em";
        lg = "0.6em";
        xl = "0.8em";
      };

      fontSize = {
        sm = "13px";
        md = "14px";
        lg = "16px";
      };

      transition = {
        fast = "0.2s";
        normal = "0.4s";
        drawerMs = "450ms";
        easing = "cubic-bezier(0.4, 0, 0.2, 1)";
      };
    };
    description = "Shared CSS sizing and timing values for waybar and other GTK widgets";
  };
}
