{
  inputs,
  pkgs,
  config,
  ...
}:
let
  theme = config.theme.colors;

  wrappedFuzzel =
    (inputs.wrappers.wrapperModules.fuzzel.apply {
      inherit pkgs;

      settings = {
        main = {
          terminal = config.apps.terminal.command;
          layer = "overlay";
          width = config.launcher.fuzzel.widthPercent;
          horizontal-pad = config.launcher.fuzzel.horizontalPad;
          vertical-pad = config.launcher.fuzzel.verticalPad;
          inner-pad = config.launcher.fuzzel.innerPad;
        };

        colors = {
          background = "${config.colors.noHash theme.bg}${config.opacity.hex.opaque}";
          text = "${config.colors.noHash theme.fg}${config.opacity.hex.opaque}";
          match = "${config.colors.noHash theme.accent}${config.opacity.hex.opaque}";
          selection = "${config.colors.noHash theme.accent}${config.opacity.hex.opaque}";
          selection-text = "${config.colors.noHash theme.bg}${config.opacity.hex.opaque}";
          border = "${config.colors.noHash theme.accent}${config.opacity.hex.opaque}";
        };

        border = {
          width = config.layout.borderWidth;
          radius = config.layout.borderRadius;
        };
      };
    }).wrapper;
in
{
  home.packages = [ wrappedFuzzel ];

  # Export the wrapped fuzzel for use by other modules
  home.sessionVariables.WRAPPED_FUZZEL = "${wrappedFuzzel}/bin/fuzzel";
}
