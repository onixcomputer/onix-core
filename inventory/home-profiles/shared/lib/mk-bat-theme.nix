# Function to generate a bat tmTheme XML from a name and color palette
{ name, colors }:
let
  c = colors;
in
''
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
    <key>name</key>
    <string>${name}</string>
    <key>settings</key>
    <array>
      <!-- Base colors -->
      <dict>
        <key>settings</key>
        <dict>
          <key>background</key>
          <string>${c.bg}</string>
          <key>foreground</key>
          <string>${c.fg}</string>
          <key>caret</key>
          <string>${c.orange}</string>
          <key>lineHighlight</key>
          <string>${c.bg_highlight}</string>
          <key>selection</key>
          <string>${c.border}</string>
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
          <string>${c.comment}</string>
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
          <string>${c.yellow}</string>
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
          <string>${c.cyan}</string>
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
          <string>${c.orange}</string>
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
          <string>${c.blue}</string>
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
          <string>${c.cyan}</string>
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
          <string>${c.fg}</string>
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
          <string>${c.orange}</string>
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
          <string>${c.cyan}</string>
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
          <string>${c.orange}</string>
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
          <string>${c.green}</string>
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
          <string>${c.green}</string>
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
          <string>${c.red}</string>
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
          <string>${c.yellow}</string>
        </dict>
      </dict>
    </array>
  </dict>
  </plist>
''
