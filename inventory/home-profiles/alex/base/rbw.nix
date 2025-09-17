{ pkgs, ... }:
let
  pinentry-rofi-custom = pkgs.writeShellScriptBin "pinentry-rofi-custom" ''
    #!/usr/bin/env bash

    # Pinentry protocol implementation using rofi
    # This provides a clean rofi interface for password prompts

    TITLE="Password Required"
    PROMPT="Password:"
    DESCRIPTION=""
    ERROR=""
    OK_BUTTON="OK"
    CANCEL_BUTTON="Cancel"

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
        SETOK*)
          OK_BUTTON="''${line#SETOK }"
          echo "OK"
          ;;
        SETCANCEL*)
          CANCEL_BUTTON="''${line#SETCANCEL }"
          echo "OK"
          ;;
        GETPIN)
          # Build the prompt message
          MESSAGE=""
          [[ -n "$DESCRIPTION" ]] && MESSAGE="$DESCRIPTION"
          # Try to use theme color if available, fallback to default
          ERROR_COLOR="f7768e"
          [[ -n "$ERROR" ]] && MESSAGE="$MESSAGE\n<span color='#$ERROR_COLOR'>$ERROR</span>"

          # Use rofi to get the password
          if [[ -n "$MESSAGE" ]]; then
            PASSWORD=$(echo -e "$MESSAGE" | ${pkgs.rofi}/bin/rofi -dmenu \
              -password \
              -p "$PROMPT" \
              -theme-str 'window {width: 450px;}' \
              -theme-str 'listview {lines: 0;}' \
              -theme-str 'entry {placeholder: "Enter password";}' \
              -markup-rows)
          else
            PASSWORD=$(${pkgs.rofi}/bin/rofi -dmenu \
              -password \
              -p "$PROMPT" \
              -theme-str 'window {width: 450px;}' \
              -theme-str 'entry {placeholder: "Enter password";}')
          fi

          if [[ $? -eq 0 ]] && [[ -n "$PASSWORD" ]]; then
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
in
{
  programs.rbw = {
    enable = true;
    settings = {
      email = "alex.decious@gmail.com";
      lock_timeout = 3600; # 1 hour
      pinentry = pinentry-rofi-custom; # Custom rofi pinentry
      base_url = "https://vault.decio.us";
    };
  };

  # Git credential helper integration
  programs.git.extraConfig.credential.helper = "${pkgs.rbw}/bin/git-credential-rbw";
}
