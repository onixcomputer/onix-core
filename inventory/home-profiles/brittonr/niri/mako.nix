{
  inputs,
  config,
  pkgs,
  ...
}:
let
  theme = config.theme.colors;

  wrappedMako =
    (inputs.wrappers.wrapperModules.mako.apply {
      inherit pkgs;

      settings = {
        # Global settings matching wired configuration
        font = "${config.font.ui} ${toString config.font.size.notification}";
        background-color = "${theme.bg}ee";
        text-color = "${theme.fg}ff";
        border-color = "${theme.accent}ff";
        border-size = config.layout.borderWidth;
        border-radius = config.layout.borderRadius;
        width = 320;
        height = 100;
        margin = 10;
        padding = 15;
        anchor = "top-right";
        layer = "overlay";
        default-timeout = 5000;
        max-visible = 5;
        max-history = 20;
        markup = 1;
        actions = 1;
        history = 1;
        format = "<b>%s</b>\\n%b";

        # Mouse bindings
        on-button-left = "invoke-default-action";
        on-button-middle = "none";
        on-button-right = "dismiss";
      };
    }).wrapper;
in
{
  home.packages = [ wrappedMako ];

  # Create systemd user service for mako
  systemd.user.services.mako = {
    Unit = {
      Description = "Lightweight Wayland notification daemon";
      Documentation = "man:mako(1)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${wrappedMako}/bin/mako";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
