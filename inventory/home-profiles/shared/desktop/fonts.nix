{ pkgs, config, ... }:
{
  # Minimal font setup - only what we actually use
  home.packages = with pkgs; [
    # Primary font with Nerd Font icons
    nerd-fonts.caskaydia-mono

    # Color emoji support
    noto-fonts-color-emoji

    # CJK (Chinese, Japanese, Korean) support - good to have
    noto-fonts-cjk-sans

    # Broad Unicode symbol coverage (Supplemental Arrows, Mathematical Operators, etc.)
    symbola
  ];

  # User-level fontconfig
  fonts.fontconfig.enable = true;

  xdg.configFile."fontconfig/conf.d/10-fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <!-- Set preferred fonts -->
      <alias>
        <family>monospace</family>
        <prefer>
          ${builtins.concatStringsSep "\n          " (
            map (f: "<family>${f}</family>") (config.font.stacks.monospace ++ config.font.stacks.cjk)
          )}
        </prefer>
      </alias>

      <alias>
        <family>sans-serif</family>
        <prefer>
          ${builtins.concatStringsSep "\n          " (
            map (f: "<family>${f}</family>") (
              [ (builtins.head config.font.stacks.sans) ] ++ config.font.stacks.cjk
            )
          )}
        </prefer>
      </alias>

      <!-- Only use emoji font when explicitly requested -->
      <alias>
        <family>emoji</family>
        <prefer>
          ${builtins.concatStringsSep "\n          " (
            map (f: "<family>${f}</family>") config.font.stacks.emoji
          )}
        </prefer>
      </alias>

      <!-- Prevent emoji font from being used for regular text/numbers -->
      <match target="pattern">
        <test name="family">
          <string>Noto Color Emoji</string>
        </test>
        <edit name="charset" mode="assign">
          <minus>
            <charset>
              <range>
                <int>0x0030</int> <!-- 0 -->
                <int>0x0039</int> <!-- 9 -->
              </range>
            </charset>
          </minus>
        </edit>
      </match>
    </fontconfig>
  '';
}
