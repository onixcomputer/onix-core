{ pkgs, config, ... }:
let
  pinentry-rofi-custom = pkgs.writeShellApplication {
    name = "pinentry-rofi-custom";
    runtimeInputs = [ pkgs.rofi ];
    text = ''
      # Pinentry protocol implementation using rofi
      # This provides a clean rofi interface for password prompts

      TITLE="Password Required"
      PROMPT="Password:"
      DESCRIPTION=""
      ERROR=""

      # Read pinentry protocol commands
      echo "OK Pleased to meet you"

      while IFS= read -r line; do
        case "$line" in
          SETTITLE*)
            TITLE="''${line#SETTITLE }"
            echo "OK"
            ;;
          SETPROMPT*)
            PROMPT="''${line#SETPROMPT }"
            echo "OK"
            ;;
          SETDESC*)
            DESCRIPTION="''${line#SETDESC }"
            echo "OK"
            ;;
          SETERROR*)
            ERROR="''${line#SETERROR }"
            echo "OK"
            ;;
          SETOK*|SETCANCEL*)
            echo "OK"
            ;;
          GETPIN)
            # Build the prompt message
            MESSAGE=""
            [[ -n "$DESCRIPTION" ]] && MESSAGE="$DESCRIPTION"
            ERROR_COLOR="f7768e"
            [[ -n "$ERROR" ]] && MESSAGE="$MESSAGE\n<span color='#$ERROR_COLOR'>$ERROR</span>"

            # Use rofi to get the password — capture exit code explicitly
            PASSWORD=""
            if [[ -n "$MESSAGE" ]]; then
              PASSWORD=$(echo -e "$MESSAGE" | rofi -dmenu \
                -password \
                -p "$PROMPT" \
                -theme-str 'window {width: 450px;}' \
                -theme-str 'listview {lines: 0;}' \
                -theme-str 'entry {placeholder: "Enter password";}' \
                -markup-rows) || true
            else
              PASSWORD=$(rofi -dmenu \
                -password \
                -p "$PROMPT" \
                -theme-str 'window {width: 450px;}' \
                -theme-str 'entry {placeholder: "Enter password";}') || true
            fi

            if [[ -n "$PASSWORD" ]]; then
              echo "D $PASSWORD"
              echo "OK"
            else
              echo "ERR 83886179 Operation cancelled"
            fi
            ;;
          BYE)
            echo "OK closing connection"
            exit 0
            ;;
          *)
            echo "OK"
            ;;
        esac
      done
    '';
  };
in
{
  imports = [ ./timeouts.nix ];

  programs.rbw = {
    enable = true;
    settings = {
      email = ""; # Override in user profile
      lock_timeout = config.timeouts.passwordCache;
      pinentry = pinentry-rofi-custom; # Custom rofi pinentry
      base_url = ""; # Override in user profile
    };
  };

  # Git credential helper integration
  programs.git.settings.credential.helper = "${pkgs.rbw}/bin/git-credential-rbw";
}
