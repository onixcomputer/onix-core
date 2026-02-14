{ config, ... }:
{
  fonts.fontconfig.enable = true;

  xdg.configFile."fontconfig/fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <!-- Enable anti-aliasing -->
      <match target="font">
        <edit mode="assign" name="antialias">
          <bool>true</bool>
        </edit>
      </match>

      <!-- Enable hinting -->
      <match target="font">
        <edit mode="assign" name="hinting">
          <bool>true</bool>
        </edit>
      </match>

      <!-- Set hinting style to slight -->
      <match target="font">
        <edit mode="assign" name="hintstyle">
          <const>hintslight</const>
        </edit>
      </match>

      <!-- Enable subpixel rendering -->
      <match target="font">
        <edit mode="assign" name="rgba">
          <const>rgb</const>
        </edit>
      </match>

      <!-- LCD filter -->
      <match target="font">
        <edit mode="assign" name="lcdfilter">
          <const>lcddefault</const>
        </edit>
      </match>

      <!-- Default font families -->
      <alias>
        <family>serif</family>
        <prefer>
          ${builtins.concatStringsSep "\n          " (
            map (f: "<family>${f}</family>") config.font.stacks.serif
          )}
        </prefer>
      </alias>

      <alias>
        <family>sans-serif</family>
        <prefer>
          ${builtins.concatStringsSep "\n          " (
            map (f: "<family>${f}</family>") config.font.stacks.sans
          )}
        </prefer>
      </alias>

      <alias>
        <family>monospace</family>
        <prefer>
          ${builtins.concatStringsSep "\n          " (
            map (f: "<family>${f}</family>") config.font.stacks.monospace
          )}
        </prefer>
      </alias>

      <!-- Reject bitmap fonts -->
      <selectfont>
        <rejectfont>
          <pattern>
            <patelt name="scalable">
              <bool>false</bool>
            </patelt>
          </pattern>
        </rejectfont>
      </selectfont>
    </fontconfig>
  '';
}
