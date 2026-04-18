# Unified keymap — source of truth for all keybindings.
#
# Consumed by: niri, wezterm, kitty, helix, tridactyl, zellij, shell-keybinds.
# Validated at `ncl export` time — typos fail immediately instead of
# silently breaking one of the five consumers.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/keymap.ncl
#   3. Commit .ncl
let Key =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "key must be a non-empty string" },
  }
  )
in

{
  # Directional navigation (vim hjkl)
  nav | { left | Key, down | Key, up | Key, right | Key } = {
    left = "h",
    down = "j",
    up = "k",
    right = "l",
  },

  # Word-level motion
  word | { forward | Key, backward | Key, end | Key } = {
    forward = "w",
    backward = "b",
    end = "e",
  },

  # Page-level motion
  page | { up | Key, down | Key } = {
    up = "u",
    down = "d",
  },

  # Line start/end (0 = Home, 4 = $ position)
  line | { start | Key, end | Key } = {
    start = "0",
    end = "4",
  },

  # Leader key
  leader | Key = "space",

  # Actions under leader prefix
  leaderActions
    | {
      filePicker | Key,
      save | Key,
      quit | Key,
      search | Key,
      bufferPicker | Key,
      format | Key,
      close | Key,
      directoryBuffer | Key,
      directoryApply | Key,
      directoryRefresh | Key,
      directoryOpenEntry | Key,
      directoryParent | Key,
      directoryMarkToggle | Key,
      directoryFlagDelete | Key,
      directoryClearMarks | Key,
      directoryCopyPreview | Key,
      directoryCopyApply | Key,
      directoryMovePreview | Key,
      directoryMoveApply | Key,
      directorySymlinkPreview | Key,
      directorySymlinkApply | Key,
      directoryRelativeSymlinkPreview | Key,
      directoryRelativeSymlinkApply | Key,
      directoryTransformLowerPreview | Key,
      directoryTransformLowerApply | Key,
      directoryTransformUpperPreview | Key,
      directoryTransformUpperApply | Key,
      directorySubdirInsert | Key,
      directorySubdirCollapse | Key,
      directorySubdirRefresh | Key,
    }
    = {
      filePicker = "space",
      save = "w",
      quit = "q",
      search = "/",
      bufferPicker = "b",
      format = "f",
      close = "d",
      directoryBuffer = "o",
      directoryApply = "a",
      directoryRefresh = "r",
      directoryOpenEntry = "e",
      directoryParent = "u",
      directoryMarkToggle = "m",
      directoryFlagDelete = "x",
      directoryClearMarks = "c",
      directoryCopyPreview = "y",
      directoryCopyApply = "Y",
      directoryMovePreview = "v",
      directoryMoveApply = "V",
      directorySymlinkPreview = "s",
      directorySymlinkApply = "S",
      directoryRelativeSymlinkPreview = "n",
      directoryRelativeSymlinkApply = "N",
      directoryTransformLowerPreview = "l",
      directoryTransformLowerApply = "L",
      directoryTransformUpperPreview = "h",
      directoryTransformUpperApply = "H",
      directorySubdirInsert = "i",
      directorySubdirCollapse = "k",
      directorySubdirRefresh = "j",
    },

  # Goto prefix (g + key)
  goto
    | {
      prefix | Key,
      top | Key,
      bottom | Key,
      nextTab | Key,
      prevTab | Key,
    }
    = {
      prefix = "g",
      top = "g",
      bottom = "e",
      nextTab = "t",
      prevTab = "T",
    },

  # Tab/buffer navigation
  tabs | { next | Key, prev | Key } = {
    next = "K",
    prev = "J",
  },

  # Modifier conventions per context
  modifiers
    | {
      wm | Key,
      secondary | Key,
      terminal | Key,
      insertNav | Key,
      systemNav | Key,
    }
    = {
      wm = "Mod",
      secondary = "Alt",
      terminal = "Ctrl+Shift",
      insertNav = "Alt",
      systemNav = "CapsLock",
    },

  # Characters for link hint overlays (tridactyl etc.)
  hintChars | Key = "neiohtsrad",

  # Terminal emulator action keys (used with terminal modifier)
  terminalActions
    | {
      copy | Key,
      paste | Key,
      newTab | Key,
      closeTab | Key,
      nextTab | Key,
      prevTab | Key,
      newWindow | Key,
      closeWindow | Key,
      nextWindow | Key,
      prevWindow | Key,
      fontUp | Key,
      fontDown | Key,
      fontReset | Key,
      scrollUp | Key,
      scrollDown | Key,
      scrollPageUp | Key,
      scrollPageDown | Key,
      scrollHome | Key,
      scrollEnd | Key,
      clearScrollback | Key,
      search | Key,
      quickSelect | Key,
      copyMode | Key,
      commandPalette | Key,
      promptPrev | Key,
      promptNext | Key,
    }
    = {
      copy = "c",
      paste = "v",
      newTab = "t",
      closeTab = "q",
      nextTab = "right",
      prevTab = "left",
      newWindow = "enter",
      closeWindow = "w",
      nextWindow = "]",
      prevWindow = "[",
      fontUp = "equal",
      fontDown = "minus",
      fontReset = "0",
      scrollUp = "up",
      scrollDown = "down",
      scrollPageUp = "page_up",
      scrollPageDown = "page_down",
      scrollHome = "home",
      scrollEnd = "end",
      clearScrollback = "k",
      search = "/",
      quickSelect = "s",
      copyMode = "x",
      commandPalette = "p",
      promptPrev = "u",
      promptNext = "d",
    },

  # Window manager actions (Mod + key)
  wm
    | {
      close | Key,
      terminal | Key,
      browser | Key,
      fileManager | Key,
      launcher | Key,
      clipboard | Key,
      screenshot | Key,
      toggleTabs | Key,
      fullscreen | Key,
      maxColumn | Key,
      presetWidth | Key,
      overview | Key,
      sysmon | Key,
      reload | Key,
      themeToggle | Key,
    }
    = {
      close = "Q",
      terminal = "Return",
      browser = "B",
      fileManager = "F",
      launcher = "Space",
      clipboard = "V",
      screenshot = "Shift+S",
      toggleTabs = "W",
      fullscreen = "Shift+I",
      maxColumn = "M",
      presetWidth = "P",
      overview = "Tab",
      sysmon = "S",
      reload = "Shift+R",
      themeToggle = "T",
    },
}
