{
  lib,
  writeShellApplication,
  curl,
  xdg-utils,
}:

writeShellApplication {
  name = "open-notebook";
  runtimeInputs = [
    curl
    xdg-utils
  ];
  text = ''
    ui_url="http://127.0.0.1:8502"
    api_url="http://127.0.0.1:5055/docs"

    case "''${1:-open}" in
      open)
        exec xdg-open "$ui_url"
        ;;
      api)
        exec xdg-open "$api_url"
        ;;
      status)
        if \
          curl --fail --silent --show-error "$api_url" > /dev/null \
          && curl --fail --silent --show-error "$ui_url" > /dev/null
        then
          printf 'Open Notebook is running.\nUI: %s\nAPI: %s\n' "$ui_url" "$api_url"
        else
          printf 'Open Notebook is not fully responding. UI=%s API=%s\n' "$ui_url" "$api_url" >&2
          exit 1
        fi
        ;;
      *)
        printf 'usage: open-notebook [open|api|status]\n' >&2
        exit 2
        ;;
    esac
  '';

  meta = {
    description = "Launcher for the local Open Notebook service";
    homepage = "https://github.com/lfnovo/open-notebook";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "open-notebook";
  };
}
