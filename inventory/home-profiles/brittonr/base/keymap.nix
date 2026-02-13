{ lib, ... }:
{
  options.keymap = {
    nav = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        left = "h";
        down = "j";
        up = "k";
        right = "l";
      };
      description = "Directional navigation keys (hjkl)";
    };

    word = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        forward = "w";
        backward = "b";
        end = "e";
      };
      description = "Word-level motion keys";
    };

    page = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        up = "u";
        down = "d";
      };
      description = "Page-level motion keys";
    };

    line = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        start = "0";
        end = "4";
      };
      description = "Line start/end keys (0 = Home, 4 = $ position)";
    };

    leader = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "space";
      description = "Leader key";
    };

    leaderActions = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        filePicker = "space";
        save = "w";
        quit = "q";
        search = "/";
        bufferPicker = "b";
        format = "f";
        close = "d";
      };
      description = "Actions available under leader prefix";
    };

    goto = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        prefix = "g";
        top = "g";
        bottom = "e";
        nextTab = "t";
        prevTab = "T";
      };
      description = "Goto prefix (g + key)";
    };

    tabs = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        next = "K";
        prev = "J";
      };
      description = "Tab/buffer navigation in normal context";
    };

    modifiers = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        wm = "Mod";
        secondary = "Alt";
        terminal = "Ctrl+Shift";
        insertNav = "Alt";
        systemNav = "CapsLock";
      };
      description = "Modifier conventions per context";
    };

    wm = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        close = "Q";
        terminal = "Return";
        browser = "B";
        fileManager = "F";
        launcher = "Space";
        clipboard = "V";
        screenshot = "Shift+S";
        toggleTabs = "W";
        fullscreen = "Shift+I";
        maxColumn = "M";
        presetWidth = "P";
        overview = "Tab";
        sysmon = "S";
        reload = "Shift+R";
        themeToggle = "T";
      };
      description = "Window manager actions (Mod + key)";
    };
  };
}
