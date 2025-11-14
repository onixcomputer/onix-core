{ pkgs, ... }:
{
  programs.bat = {
    enable = true;
    config = {
      pager = "never";
      style = "numbers,changes,header";
      theme = "onix-dark";
    };
    themes = {
      onix-dark = {
        src = pkgs.writeText "onix-dark.tmTheme" ''
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>name</key>
            <string>Onix Dark</string>
            <key>settings</key>
            <array>
              <!-- Base colors -->
              <dict>
                <key>settings</key>
                <dict>
                  <key>background</key>
                  <string>#1a1a1a</string>
                  <key>foreground</key>
                  <string>#e6e6e6</string>
                  <key>caret</key>
                  <string>#ff6600</string>
                  <key>lineHighlight</key>
                  <string>#262626</string>
                  <key>selection</key>
                  <string>#404040</string>
                </dict>
              </dict>
              <!-- Comments -->
              <dict>
                <key>name</key>
                <string>Comment</string>
                <key>scope</key>
                <string>comment</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#595959</string>
                  <key>fontStyle</key>
                  <string>italic</string>
                </dict>
              </dict>
              <!-- Strings -->
              <dict>
                <key>name</key>
                <string>String</string>
                <key>scope</key>
                <string>string</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#ffaa00</string>
                </dict>
              </dict>
              <!-- Numbers -->
              <dict>
                <key>name</key>
                <string>Number</string>
                <key>scope</key>
                <string>constant.numeric</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#00ffff</string>
                </dict>
              </dict>
              <!-- Keywords -->
              <dict>
                <key>name</key>
                <string>Keyword</string>
                <key>scope</key>
                <string>keyword</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#ff6600</string>
                  <key>fontStyle</key>
                  <string>bold</string>
                </dict>
              </dict>
              <!-- Functions -->
              <dict>
                <key>name</key>
                <string>Function</string>
                <key>scope</key>
                <string>entity.name.function</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#4488ff</string>
                </dict>
              </dict>
              <!-- Types -->
              <dict>
                <key>name</key>
                <string>Type</string>
                <key>scope</key>
                <string>entity.name.type, entity.name.class</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#00ffff</string>
                </dict>
              </dict>
              <!-- Variables -->
              <dict>
                <key>name</key>
                <string>Variable</string>
                <key>scope</key>
                <string>variable</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#e6e6e6</string>
                </dict>
              </dict>
              <!-- Operators -->
              <dict>
                <key>name</key>
                <string>Operator</string>
                <key>scope</key>
                <string>keyword.operator</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#ff6600</string>
                </dict>
              </dict>
              <!-- Constants -->
              <dict>
                <key>name</key>
                <string>Constant</string>
                <key>scope</key>
                <string>constant</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#00ffff</string>
                </dict>
              </dict>
              <!-- Markup headers -->
              <dict>
                <key>name</key>
                <string>Markup Heading</string>
                <key>scope</key>
                <string>markup.heading</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#ff6600</string>
                  <key>fontStyle</key>
                  <string>bold</string>
                </dict>
              </dict>
              <!-- Markup bold -->
              <dict>
                <key>name</key>
                <string>Markup Bold</string>
                <key>scope</key>
                <string>markup.bold</string>
                <key>settings</key>
                <dict>
                  <key>fontStyle</key>
                  <string>bold</string>
                </dict>
              </dict>
              <!-- Markup italic -->
              <dict>
                <key>name</key>
                <string>Markup Italic</string>
                <key>scope</key>
                <string>markup.italic</string>
                <key>settings</key>
                <dict>
                  <key>fontStyle</key>
                  <string>italic</string>
                </dict>
              </dict>
              <!-- Markup code -->
              <dict>
                <key>name</key>
                <string>Markup Code</string>
                <key>scope</key>
                <string>markup.inline.raw, markup.fenced_code</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#44ff44</string>
                </dict>
              </dict>
              <!-- Diff Added -->
              <dict>
                <key>name</key>
                <string>Diff Added</string>
                <key>scope</key>
                <string>markup.inserted</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#44ff44</string>
                </dict>
              </dict>
              <!-- Diff Deleted -->
              <dict>
                <key>name</key>
                <string>Diff Deleted</string>
                <key>scope</key>
                <string>markup.deleted</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#ff4444</string>
                </dict>
              </dict>
              <!-- Diff Changed -->
              <dict>
                <key>name</key>
                <string>Diff Changed</string>
                <key>scope</key>
                <string>markup.changed</string>
                <key>settings</key>
                <dict>
                  <key>foreground</key>
                  <string>#ffaa00</string>
                </dict>
              </dict>
            </array>
          </dict>
          </plist>
        '';
        file = "onix-dark.tmTheme";
      };
    };
  };
}
