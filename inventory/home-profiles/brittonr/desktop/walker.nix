{ pkgs, ... }:
{
  home.packages = with pkgs; [
    walker
  ];

  # Walker configuration file
  xdg.configFile."walker/config.toml".text = ''
    # General settings
    close_when_open = true
    force_keyboard_focus = true

    [search]
    placeholder = " Search..."
    delay = 0

    [list]
    max_entries = 50
    show_initial_entries = true
    single_click = true

    [keys]
    accept_typeahead = ["tab"]
    next = ["down"]
    prev = ["up"]
    close = ["esc"]

    [builtins.applications]
    weight = 5
    name = "applications"
    placeholder = " Search..."
    prioritize_new = false
    show_generic = true
    refresh = true

    [builtins.calc]
    weight = 5
    name = "Calculator"
    placeholder = "Calculator"
    min_chars = 3

    [builtins.clipboard]
    weight = 5
    name = "clipboard"
    placeholder = "Clipboard"
    max_entries = 10
    exec = "wl-copy"

    [builtins.emojis]
    weight = 5
    name = "Emojis"
    placeholder = "Emojis"
    exec = "wl-copy"
    prefix = ":"

    [builtins.websearch]
    weight = 5
    name = "websearch"
    placeholder = "Websearch"

    [[builtins.websearch.entries]]
    name = "Google"
    url = "https://www.google.com/search?q=%TERM%"

    [[builtins.websearch.entries]]
    name = "DuckDuckGo"
    url = "https://duckduckgo.com/?q=%TERM%"

    [builtins.switcher]
    weight = 5
    name = "switcher"
    placeholder = "Switcher"
    prefix = "/"
  '';
}
