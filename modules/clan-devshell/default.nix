_: {
  _class = "clan.service";

  manifest = {
    name = "clan-devshell";
    description = "Development shell with clan vars integration and decryption testing";
    categories = [
      "Development"
      "Tools"
    ];
  };

  roles.developer = {
    interface =
      { lib, ... }:
      {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable clan development shell with vars integration on this machine";
          };

          enableSystemdService = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable systemd service to periodically test decryption";
          };

          testInterval = lib.mkOption {
            type = lib.types.str;
            default = "hourly";
            description = "How often to run the decryption tests (systemd timer format)";
          };
        };
      };

    perInstance =
      { instanceName, settings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            inputs,
            ...
          }:
          let
            # Generator name for our test var
            testGeneratorName = "clan-vars-decryption-test-${instanceName}";

            # Get the actual path from the config (evaluated at build time)
            testVarPath = config.clan.core.vars.generators.${testGeneratorName}.files.test-secret.path;

            # Define the packages for the devshell
            devShellPackages = with pkgs; [
              # Basic development tools
              git
              jq
              ripgrep
              fd
              curl
              wget
              tree

              # Nix tools
              nix-tree
              nixfmt-rfc-style

              # Clan CLI
              inputs.clan-core.packages.${pkgs.system}.clan-cli
            ];

            # Define the shell hook
            devShellHook = ''
              echo "╔══════════════════════════════════════════════════════╗"
              echo "║           Clan Development Shell                      ║"
              echo "╚══════════════════════════════════════════════════════╝"
              echo ""

              # Test if we can access clan vars
              if [ -r "${testVarPath}" ]; then
                export CLAN_TEST_VAR="$(cat ${testVarPath})"
                echo "✓ Clan vars accessible"
                echo "  CLAN_TEST_VAR is set to: $CLAN_TEST_VAR"
              else
                echo "⚠ Clan vars not accessible from this shell"
              fi

              echo ""
              echo "Available tools:"
              echo "  clan         - Clan CLI tool"
              echo "  git, jq, ripgrep, fd, curl, wget, tree"
              echo "  nix-tree, nixfmt-rfc-style"
              echo ""
              echo "Clan commands:"
              echo "  clan-vars-test   - Test var decryption"
              echo "  clan-vars-status - Show test status"
              echo ""
              echo "Environment:"
              echo "  Instance: ${instanceName}"
              echo "  Machine: $(hostname)"
              echo "  Working directory: $(pwd)"
              echo ""
            '';

            # Entry script for the devshell
            devShellScript = pkgs.writeShellScriptBin "clan-devshell" ''
              #!/usr/bin/env bash
              echo "Entering Clan development shell..."

              # Create a temporary init file with the shell hook
              INIT_FILE=$(mktemp)
              cat > "$INIT_FILE" <<'EOF'
              # Source the default bashrc if it exists
              [ -f ~/.bashrc ] && source ~/.bashrc

              # Setup the devshell environment
              export PATH="${lib.makeBinPath devShellPackages}:$PATH"

              # Run the shell hook
              ${devShellHook}
              EOF

              # Start bash with our init file
              ${pkgs.bash}/bin/bash --init-file "$INIT_FILE"

              # Cleanup
              rm -f "$INIT_FILE"
            '';

            # Build the test script
            testScript = pkgs.writeShellScriptBin "clan-vars-test" ''
              #!/usr/bin/env bash
              set -euo pipefail

              echo "╔══════════════════════════════════════════════════════╗"
              echo "║        Clan Vars Decryption Test - ${instanceName}    ║"
              echo "╚══════════════════════════════════════════════════════╝"
              echo ""

              # Test our test var using the nix-evaluated path
              echo -n "Testing decryption test var... "
              TEST_VAR_PATH="${testVarPath}"

              if [ -r "$TEST_VAR_PATH" ]; then
                TEST_CONTENT=$(cat "$TEST_VAR_PATH" 2>/dev/null || echo "FAILED_TO_DECRYPT")
                if [ "$TEST_CONTENT" = "DECRYPTION_TEST_SUCCESSFUL" ]; then
                  echo "✓ PASSED"
                  echo ""
                  echo "This machine can successfully decrypt clan vars!"
                  echo "Test var content verified: $TEST_CONTENT"
                  echo "Path used: $TEST_VAR_PATH"
                  exit 0
                else
                  echo "✗ FAILED"
                  echo ""
                  echo "File exists but content unexpected: $TEST_CONTENT"
                  echo "This indicates a decryption or generation issue."
                  exit 1
                fi
              else
                echo "✗ FAILED"
                echo ""
                echo "Test var file not accessible at: $TEST_VAR_PATH"
                echo "Run 'clan vars generate' to create the test var."
                exit 1
              fi
            '';

            # Status check script
            statusScript = pkgs.writeShellScriptBin "clan-vars-status" ''
              #!/usr/bin/env bash
              set -euo pipefail

              echo "Clan Vars Decryption Test Status"
              echo "================================="
              echo ""
              echo "Test Generator: ${testGeneratorName}"
              echo "Test File: test-secret"
              echo "Test Path: ${testVarPath}"
              echo ""
              echo "This test verifies that this machine can:"
              echo "  1. Access the clan vars system"
              echo "  2. Decrypt secrets it has access to"
              echo "  3. Read the decrypted content correctly"
              echo ""
              echo "Run 'clan-vars-test' to execute the decryption test"
              echo "Run 'systemctl status clan-vars-test-${instanceName}' to see service status"
            '';

          in
          lib.mkIf settings.enable {
            # Create the test generator
            clan.core.vars.generators.${testGeneratorName} = {
              share = false; # This is a local test, not shared
              files.test-secret = {
                secret = true; # Mark as secret to test decryption
                deploy = true; # Ensure it's deployed to /run/secrets/vars/
                mode = "0444"; # Make it world-readable for testing purposes
              };

              script = ''
                # Generate a simple test secret
                echo "DECRYPTION_TEST_SUCCESSFUL" > "$out/test-secret"
              '';
            };

            # Install the scripts
            environment.systemPackages = [
              testScript
              statusScript
              devShellScript
            ];

            # Create systemd service and timer if enabled
            systemd.services."clan-vars-test-${instanceName}" = lib.mkIf settings.enableSystemdService {
              description = "Clan Vars Decryption Test - ${instanceName}";
              after = [ "multi-user.target" ];

              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${testScript}/bin/clan-vars-test";
                StandardOutput = "journal";
                StandardError = "journal";
              };
            };

            systemd.timers."clan-vars-test-${instanceName}" = lib.mkIf settings.enableSystemdService {
              description = "Timer for Clan Vars Decryption Test - ${instanceName}";
              wantedBy = [ "timers.target" ];

              timerConfig = {
                OnCalendar = settings.testInterval;
                Persistent = true;
              };
            };

            # Add activation script to show availability
            system.activationScripts."clan-devshell-${instanceName}-info" = ''
              echo "Clan development shell '${instanceName}' is available."
              echo "Run 'clan-devshell' to enter the development environment."
              echo "Run 'clan-vars-test' to test decryption capabilities."
              ${lib.optionalString settings.enableSystemdService ''
                echo "Automatic testing is scheduled: ${settings.testInterval}"
              ''}
            '';
          };
      };
  };
}
