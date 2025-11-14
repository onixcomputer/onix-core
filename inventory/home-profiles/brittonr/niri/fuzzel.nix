{ inputs, pkgs, ... }:
let
  wrappedFuzzel =
    (inputs.wrappers-niri.wrapperModules.fuzzel.apply {
      inherit pkgs;

      settings = {
        main = {
          terminal = "${pkgs.kitty}/bin/kitty";
          layer = "overlay";
          width = 50;
          horizontal-pad = 20;
          vertical-pad = 10;
          inner-pad = 10;
        };

        colors = {
          background = "1a1a1aff";
          text = "ffffffff";
          match = "ff6600ff";
          selection = "ff6600ff";
          selection-text = "000000ff";
          border = "ff6600ff";
        };

        border = {
          width = 2;
          radius = 0;
        };
      };
    }).wrapper;
in
{
  home.packages = [ wrappedFuzzel ];

  # Export the wrapped fuzzel for use by other modules
  home.sessionVariables.WRAPPED_FUZZEL = "${wrappedFuzzel}/bin/fuzzel";
}
