{ pkgs, ... }:
let
  # Custom goose-cli with latest version (1.9.3) to fix streaming issues
  goose-cli-latest = pkgs.rustPlatform.buildRustPackage rec {
    pname = "goose-cli";
    version = "1.9.3";

    src = pkgs.fetchFromGitHub {
      owner = "block";
      repo = "goose";
      rev = "v${version}";
      hash = "sha256-cw4iGvfgJ2dGtf6om0WLVVmieeVGxSPPuUYss1rYcS8=";
    };

    cargoHash = "sha256-/HaxjQDrBYKLP5lamx7TIbYUtIdCfbqZ5oQ1rK4T8uA=";

    nativeBuildInputs = with pkgs; [
      pkg-config
      protobuf
    ];
    buildInputs = with pkgs; [ dbus ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.xorg.libxcb ];

    doCheck = false; # Tests require network access

    meta = {
      description = "Open-source, extensible AI agent";
      homepage = "https://github.com/block/goose";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "goose";
    };
  };
in
{
  # LLM Client tools - connects to remote ollama servers
  # Use this tag for machines that need AI coding assistance but don't run the LLM server

  # Install client tools only
  environment.systemPackages = with pkgs; [
    opencode # AI coding agent that works well with remote Ollama
    goose-cli-latest # AI coding assistant with latest version (1.9.3) - should fix streaming issues

    # Optional: direct ollama CLI for manual interaction
    ollama # CLI tool can connect to remote servers
  ];

  # Opencode configuration for remote ollama server
  environment.etc."opencode/opencode.json".text = ''
    {
      "$schema": "https://opencode.ai/config.json",
      "provider": {
        "ollama": {
          "npm": "@ai-sdk/openai-compatible",
          "name": "Ollama (aspen1)",
          "options": {
            "baseURL": "http://aspen1:11434/v1"
          },
          "models": {
            "qwen2.5:7b": {
              "name": "Qwen 2.5 7B"
            },
            "qwen2.5:32b": {
              "name": "Qwen 2.5 32B"
            }
          }
        }
      }
    }
  '';

  # Goose configuration for remote ollama server
  environment.etc."goose/config.yaml".text = ''
    provider: ollama
    model: qwen2.5:7b
    endpoint: http://aspen1:11434
    context_length: 32768
    temperature: 0.7
    max_tokens: 4096
    timeout: 300

    # Performance settings
    parallel_requests: 2
    stream: false

    # Enable useful extensions (optional - will fail gracefully if not available)
    extensions:
      - file_operations
      - terminal_commands
      - code_generation
  '';

  # Project hints for AI tools
  environment.etc."goosehints".text = ''
    # Onix-Core NixOS Configuration Project

    This is a NixOS configuration repository using the Onix framework.

    ## Key Information:
    - Uses Nix flakes and NixOS modules
    - Machine configurations in inventory/core/machines.nix
    - Service tags in inventory/tags/
    - Focus on system administration and DevOps tasks
    - Prefer absolute paths when referencing files

    ## Common Tasks:
    - Configuring NixOS services
    - Managing machine deployments with `clan deploy <machine>`
    - Working with systemd services
    - GPU/AI workload optimization
    - Network and firewall configuration

    ## Code Style:
    - Use Nix expressions with proper formatting
    - Follow existing patterns in the codebase
    - Include comments for complex configurations
    - Test configurations before deployment
  '';

  # Create user-specific AI tool configs
  system.activationScripts.ai-client-configs = ''
        # Ensure config directories exist for users
        for user in brittonr; do
          if [ -d "/home/$user" ]; then
            # Goose configuration
            mkdir -p "/home/$user/.config/goose"
            if [ ! -f "/home/$user/.config/goose/config.yaml" ] || [ "/etc/goose/config.yaml" -nt "/home/$user/.config/goose/config.yaml" ]; then
              cp "/etc/goose/config.yaml" "/home/$user/.config/goose/config.yaml"
              chown "$user:users" "/home/$user/.config/goose/config.yaml"
            fi

            # Opencode configuration
            mkdir -p "/home/$user/.config/opencode"
            if [ ! -f "/home/$user/.config/opencode/opencode.json" ] || [ "/etc/opencode/opencode.json" -nt "/home/$user/.config/opencode/opencode.json" ]; then
              cp "/etc/opencode/opencode.json" "/home/$user/.config/opencode/opencode.json"
              chown "$user:users" "/home/$user/.config/opencode/opencode.json"
            fi

            # Set default opencode config
            cat > "/home/$user/.config/opencode/config.json" << 'EOFC'
    {
      "$schema": "https://opencode.ai/config.json",
      "model": "ollama/qwen2.5:7b",
      "theme": "opencode",
      "autoshare": false,
      "autoupdate": true
    }
    EOFC
            chown "$user:users" "/home/$user/.config/opencode/config.json"
          fi
        done
  '';
}
