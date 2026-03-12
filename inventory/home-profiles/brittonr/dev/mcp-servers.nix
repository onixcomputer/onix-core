# MCP (Model Context Protocol) servers for AI coding assistants
{ pkgs, inputs, ... }:
let
  mcp-pkgs = inputs.mcp-servers-nix.packages.${pkgs.stdenv.hostPlatform.system};

  # MCP server packages - referenced by full path in mcpConfig below.
  # NOT added to home.packages to avoid node_modules path collisions
  # (they share @modelcontextprotocol/servers paths from the npm monorepo)

  # Generate JSON config for Claude Code settings.json
  mcpConfig = {
    context7 = {
      command = "${mcp-pkgs.context7-mcp}/bin/context7-mcp";
      args = [ ];
    };
    filesystem = {
      command = "${mcp-pkgs.mcp-server-filesystem}/bin/mcp-server-filesystem";
      args = [
        "."
        ".."
      ];
    };
    git = {
      command = "${mcp-pkgs.mcp-server-git}/bin/mcp-server-git";
      args = [ ];
    };
    memory = {
      command = "${mcp-pkgs.mcp-server-memory}/bin/mcp-server-memory";
      args = [ ];
    };
    sequential-thinking = {
      command = "${mcp-pkgs.mcp-server-sequential-thinking}/bin/mcp-server-sequential-thinking";
      args = [ ];
    };
    time = {
      command = "${mcp-pkgs.mcp-server-time}/bin/mcp-server-time";
      args = [ ];
    };
    fetch = {
      command = "${mcp-pkgs.mcp-server-fetch}/bin/mcp-server-fetch";
      args = [ ];
    };
    playwright = {
      command = "${mcp-pkgs.playwright-mcp}/bin/mcp-server-playwright";
      args = [ ];
    };
  };

  mcpConfigJson = builtins.toJSON mcpConfig;

  # Script to update Claude Code settings.json with MCP servers
  updateMcpConfig = pkgs.writeShellScriptBin "mcp-update-claude" ''
    SETTINGS_FILE="$HOME/.claude/settings.json"

    if [ ! -f "$SETTINGS_FILE" ]; then
      echo "Error: $SETTINGS_FILE not found"
      exit 1
    fi

    # Backup current settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"

    # Update mcpServers in settings.json
    ${pkgs.jq}/bin/jq --argjson mcp '${mcpConfigJson}' '.mcpServers = (.mcpServers // {}) + $mcp' \
      "$SETTINGS_FILE.bak" > "$SETTINGS_FILE"

    echo "Updated MCP servers in $SETTINGS_FILE"
    echo "Backup saved to $SETTINGS_FILE.bak"
    echo ""
    echo "Added servers:"
    ${pkgs.jq}/bin/jq -r '.mcpServers | keys[]' "$SETTINGS_FILE" | sort
  '';
in
{
  home.packages = [ updateMcpConfig ];

  # Write the MCP config as a reference file
  home.file.".config/mcp-servers/claude-code.json".text = builtins.toJSON {
    mcpServers = mcpConfig;
  };
}
