# Niri keybindings — thin stub over niri-keybinds.ncl.
#
# Binding definitions live in niri-keybinds.ncl.
# This module resolves @placeholder@ tokens to store paths and
# renders the structured bindings to a KDL string for niri.
{
  inputs,
  config,
  pkgs,
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./niri-keybinds.ncl;

  subs = {
    "@terminal@" = config.apps.terminal.command;
    "@browser@" = config.apps.browser.command;
    "@fileManager@" = config.apps.fileManager.command;
    "@sysmon@" = config.apps.sysmon.command;
    "@xcwd@" = "${pkgs.xcwd}/bin/xcwd";
    "@noctalia-shell@" = "noctalia-shell";
  };

  resolve =
    s:
    builtins.foldl' (acc: key: builtins.replaceStrings [ key ] [ subs.${key} ] acc) s (
      builtins.attrNames subs
    );

  # Render a single action binding to KDL
  renderAction =
    b:
    let
      actionStr = if b ? args then "${b.action} ${b.args};" else "${b.action};";
    in
    "${b.key} { ${actionStr} }";

  # Render a single spawn binding to KDL
  renderSpawn =
    b:
    let
      args = builtins.concatStringsSep " " (map (a: ''"${resolve a}"'') b.spawn);
    in
    "${b.key} { spawn ${args}; }";

  # Render a raw binding to KDL
  renderRaw =
    b:
    let
      # Unescape %% back to % for KDL output
      rawStr = builtins.replaceStrings [ "%%" ] [ "%" ] b.raw;
    in
    "${b.key} { ${rawStr}; }";

  # Collect all binding groups and render
  actionGroups = map (g: data.${g}) [
    "windowManagement"
    "focusNav"
    "moveNav"
    "monitorNav"
    "monitorMove"
    "columns"
    "workspaceFocus"
    "workspaceMove"
    "captureActions"
  ];

  spawnGroups = map (g: data.${g}) [
    "windowManagementSpawn"
    "applications"
    "noctalia"
    "media"
    "capture"
  ];

  rawGroups = map (g: data.${g}) [
    "windowManagementRaw"
    "resize"
  ];

  allActions = builtins.concatLists actionGroups;
  allSpawns = builtins.concatLists spawnGroups;
  allRaws = builtins.concatLists rawGroups;

  indent = "      ";
  lines =
    (map (b: "${indent}${renderAction b}") allActions)
    ++ (map (b: "${indent}${renderSpawn b}") allSpawns)
    ++ (map (b: "${indent}${renderRaw b}") allRaws);
in
''
    binds {
  ${builtins.concatStringsSep "\n" lines}
    }
''
