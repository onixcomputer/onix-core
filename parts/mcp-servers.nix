# MCP (Model Context Protocol) servers configuration
# Provides MCP servers for AI coding assistants like Claude Code and VS Code
_: {
  perSystem =
    { lib, ... }:
    {
      mcp-servers = {
        # Base configuration applied to all enabled flavors
        programs = {
          # Filesystem access for reading/writing files in the project
          filesystem = {
            enable = true;
            args = [ "." ];
          };

          # Git operations for version control
          git.enable = true;

          # Context7 for documentation lookup
          context7.enable = true;

          # Memory for persistent context across sessions
          memory.enable = true;

          # Time utilities
          time.enable = true;

          # Sequential thinking for complex reasoning
          sequential-thinking.enable = true;

          # TODO: nixos MCP server has dependency conflict (requires mcp<1.17.0 but 1.25.0 is used)
          # nixos.enable = true;

          # HTTP fetching for documentation and APIs
          fetch.enable = true;

          # Browser automation for testing
          playwright.enable = true;
        };

        # Flavor-specific configuration
        flavors = {
          # Claude Code configuration (generates .mcp.json)
          claude-code = {
            enable = true;
            # Extend filesystem access to parent directories for better context
            programs.filesystem.args = lib.mkForce [
              "."
              ".."
            ];
          };

          # VS Code workspace configuration (generates .vscode/mcp.json)
          vscode-workspace.enable = true;
        };
      };
    };
}
