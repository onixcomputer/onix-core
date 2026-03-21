# Status bar settings — thin stub over bar.ncl.
#
# Data and contracts live in bar.ncl.
# Theme-dependent values (calendar colors, waybar colors) are merged
# here from config.theme.data since themes are resolved at Nix eval time.
{
  inputs,
  lib,
  config,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./bar.ncl;

  theme = config.theme.data;
in
{
  options.bar = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data // {
      # Calendar colors from active theme
      calendar = {
        months = theme.orange.hex;
        days = theme.accent2.hex;
        weeks = theme.green.hex;
        weekdays = theme.yellow.hex;
        today = theme.red.hex;
      };
      # Waybar colors from active theme
      waybar = data.waybar // {
        colors = {
          bg = theme.bar_waybar.bg.hex;
          fg = theme.bar_waybar.fg.hex;
          accent = theme.bar_waybar.accent.hex;
          tooltip_bg = theme.bar_waybar.tooltip_bg.hex;
          muted = theme.bar_waybar.muted.hex;
          warning = theme.bar_waybar.warning.hex;
          critical = theme.bar_waybar.critical.hex;
          critical_bg = theme.bar_waybar.critical_bg.hex;
          charging = theme.bar_waybar.charging.hex;
        };
      };
    };
    description = "Status bar shared settings";
  };
}
