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
          width = 50;
          horizontal-pad = 20;
          vertical-pad = 10;
          inner-pad = 10;
        };

        colors = {
          background = "${builtins.substring 1 6 theme.bg}ff";
          text = "${builtins.substring 1 6 theme.fg}ff";
          match = "${builtins.substring 1 6 theme.accent}ff";
          selection = "${builtins.substring 1 6 theme.accent}ff";
          selection-text = "${builtins.substring 1 6 theme.bg}ff";
          border = "${builtins.substring 1 6 theme.accent}ff";
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
