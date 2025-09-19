_: {
  _class = "clan.service";

  manifest = {
    name = "terranix-devshell";
    description = "Development shell for Terranix/Terraform infrastructure deployments";
    categories = [
      "Development"
      "Infrastructure"
      "IaC"
    ];
  };

  roles.deployer = {
    interface =
      { lib, ... }:
      {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Terranix deployment devshell on this machine";
          };

          provider = lib.mkOption {
            type = lib.types.enum [
              "terraform"
              "opentofu"
            ];
            default = "opentofu";
            description = "Which Terraform-compatible provider to use";
          };

          workingDirectory = lib.mkOption {
            type = lib.types.str;
            default = "./infrastructure";
            description = "Working directory for Terraform/Terranix operations (absolute or relative to git root)";
            example = "./infrastructure/dev";
          };

          cloudProviders = lib.mkOption {
            type = lib.types.listOf (
              lib.types.enum [
                "cloudflare"
                "aws"
                "azure"
                "gcp"
                "hetzner"
              ]
            );
            default = [ "cloudflare" ];
            description = "Cloud providers to configure credentials for";
          };

          cloudflareConfig = lib.mkOption {
            type = lib.types.submodule {
              options = {
                apiTokenGenerator = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Clan generator containing Cloudflare API token (auto-generated if null)";
                };
                apiTokenFile = lib.mkOption {
                  type = lib.types.str;
                  default = "api_token";
                  description = "File name within the generator containing the API token";
                };
                email = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Cloudflare account email (optional)";
                };
              };
            };
            default = { };
            description = "Cloudflare provider configuration";
          };

          awsConfig = lib.mkOption {
            type = lib.types.submodule {
              options = {
                credentialsGenerator = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Clan generator containing AWS credentials";
                };
                region = lib.mkOption {
                  type = lib.types.str;
                  default = "us-east-1";
                  description = "Default AWS region";
                };
              };
            };
            default = { };
            description = "AWS provider configuration";
          };

          additionalTools = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = "Additional packages to include in the devshell";
          };

          environmentFiles = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Additional environment files to source";
          };

          preInitHooks = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Commands to run before initializing Terraform";
          };

          postInitHooks = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Commands to run after initializing Terraform";
          };

          s3Backend = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Use Garage S3 backend for Terraform state";
                };
                endpoint = lib.mkOption {
                  type = lib.types.str;
                  default = "localhost:3900";
                  description = "Garage S3 endpoint URL";
                };
                bucket = lib.mkOption {
                  type = lib.types.str;
                  default = "terraform-state";
                  description = "S3 bucket name for Terraform state";
                };
                region = lib.mkOption {
                  type = lib.types.str;
                  default = "garage";
                  description = "AWS region (use 'garage' for Garage)";
                };
                credentialsGenerator = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Clan generator name for S3 credentials (auto-generated if null)";
                };
                dynamoDbTable = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "DynamoDB table for state locking (Garage K2V API)";
                };
              };
            };
            default = { };
            description = "S3 backend configuration for Terraform state";
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
            # Select the Terraform provider
            terraform = if settings.provider == "opentofu" then pkgs.opentofu else pkgs.terraform;

            # S3 credentials generator name - match existing garage pattern
            s3GeneratorName =
              if settings.s3Backend.credentialsGenerator != null then
                settings.s3Backend.credentialsGenerator
              else
                "garage-terraform-terraform-state";

            # Resolve working directory (handle relative paths)
            resolvedWorkingDirectory =
              if lib.hasPrefix "/" settings.workingDirectory then
                settings.workingDirectory # Absolute path
              else
                "\${GIT_ROOT}/${settings.workingDirectory}"; # Relative to git root

            # Build list of infrastructure tools
            infraTools =
              with pkgs;
              [
                # Core tools
                terraform
                terranix
                terraform-ls
                tflint

                # State management
                git
                git-crypt

                # Cloud CLIs
              ]
              ++ lib.optionals (builtins.elem "cloudflare" settings.cloudProviders) [
                pkgs.cloudflared
              ]
              ++ lib.optionals (builtins.elem "aws" settings.cloudProviders) [
                pkgs.awscli2
              ]
              ++ lib.optionals (builtins.elem "azure" settings.cloudProviders) [
                pkgs.azure-cli
              ]
              ++ lib.optionals (builtins.elem "gcp" settings.cloudProviders) [
                pkgs.google-cloud-sdk
              ];

            # All packages for the devshell
            devShellPackages =
              infraTools
              ++ [
                # Development utilities
                pkgs.jq
                pkgs.yq
                pkgs.curl
                pkgs.wget
                pkgs.ripgrep
                pkgs.fd
                pkgs.tree

                # Nix tools
                pkgs.nixfmt-rfc-style
                pkgs.nix-tree

                # Clan CLI
                inputs.clan-core.packages.${pkgs.system}.clan-cli
              ]
              ++ settings.additionalTools;

            # Build the environment setup script
            envSetupScript = ''
              # Find git repo root (fail if not in a git repo)
              export GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (echo "Error: Not in a git repository" >&2; exit 1))"

              # Setup Terraform/OpenTofu environment
              export TF_CLI_CONFIG_FILE="$HOME/.terraformrc"
              export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
              export TF_LOG_PATH="/tmp/terraform-${instanceName}.log"

              # Create necessary directories
              mkdir -p "$TF_PLUGIN_CACHE_DIR"
              mkdir -p "${resolvedWorkingDirectory}"

              # Setup S3 backend
              ${lib.optionalString settings.s3Backend.enable ''
                export AWS_ENDPOINT_URL_S3="${settings.s3Backend.endpoint}"
                export AWS_DEFAULT_REGION="${settings.s3Backend.region}"
                echo "ℹ S3 backend configured at ${settings.s3Backend.endpoint}"
              ''}
            '';

            # Build the credentials setup script using systemd credentials
            credentialsScript = ''
              echo "Setting up cloud provider credentials from clan vars..."
              echo ""

              # Get machine hostname for clan vars
              MACHINE_NAME="$(hostname)"
              echo "Loading credentials for machine: $MACHINE_NAME"

              ${lib.optionalString settings.s3Backend.enable ''
                # Setup S3 credentials from clan vars
                echo "Loading S3 credentials..."
                if AWS_ACCESS_KEY_ID="$(clan vars get "$MACHINE_NAME" "${
                  if settings.s3Backend.credentialsGenerator != null then
                    settings.s3Backend.credentialsGenerator
                  else
                    "garage-terraform-terraform-state"
                }/s3_access_key" 2>/dev/null)" && \
                   AWS_SECRET_ACCESS_KEY="$(clan vars get "$MACHINE_NAME" "${
                     if settings.s3Backend.credentialsGenerator != null then
                       settings.s3Backend.credentialsGenerator
                     else
                       "garage-terraform-terraform-state"
                   }/s3_secret_key" 2>/dev/null)"; then
                  export AWS_ACCESS_KEY_ID
                  export AWS_SECRET_ACCESS_KEY
                  export AWS_ENDPOINT_URL_S3="${settings.s3Backend.endpoint}"
                  export AWS_DEFAULT_REGION="${settings.s3Backend.region}"
                  echo "✓ S3 backend credentials loaded from clan vars"
                else
                  echo "⚠ S3 credentials not found in clan vars"
                  echo "  Run: clan vars set $MACHINE_NAME ${
                    if settings.s3Backend.credentialsGenerator != null then
                      settings.s3Backend.credentialsGenerator
                    else
                      "garage-terraform-terraform-state"
                  }/s3_access_key <ACCESS_KEY>"
                  echo "  Run: clan vars set $MACHINE_NAME ${
                    if settings.s3Backend.credentialsGenerator != null then
                      settings.s3Backend.credentialsGenerator
                    else
                      "garage-terraform-terraform-state"
                  }/s3_secret_key <SECRET_KEY>"
                fi
              ''}

              ${lib.optionalString (builtins.elem "cloudflare" settings.cloudProviders) ''
                # Setup Cloudflare credentials from clan vars
                echo "Loading Cloudflare credentials..."
                if CLOUDFLARE_API_TOKEN="$(clan vars get "$MACHINE_NAME" "${
                  if settings.cloudflareConfig.apiTokenGenerator != null then
                    settings.cloudflareConfig.apiTokenGenerator
                  else
                    "cloudflare-${instanceName}"
                }/${settings.cloudflareConfig.apiTokenFile}" 2>/dev/null)"; then
                  export CLOUDFLARE_API_TOKEN
                  echo "✓ Cloudflare API token loaded from clan vars"
                  ${lib.optionalString (settings.cloudflareConfig.email != null) ''
                    export CLOUDFLARE_EMAIL="${settings.cloudflareConfig.email}"
                    echo "✓ Cloudflare email set"
                  ''}
                else
                  echo "⚠ Cloudflare API token not found in clan vars"
                  echo "  Run: clan vars set $MACHINE_NAME ${
                    if settings.cloudflareConfig.apiTokenGenerator != null then
                      settings.cloudflareConfig.apiTokenGenerator
                    else
                      "cloudflare-${instanceName}"
                  }/${settings.cloudflareConfig.apiTokenFile} <API_TOKEN>"
                fi
              ''}

              ${lib.optionalString (builtins.elem "aws" settings.cloudProviders) ''
                # Setup AWS credentials from clan vars
                echo "Loading AWS credentials..."
                if AWS_CREDENTIALS="$(clan vars get "$MACHINE_NAME" "${
                  if settings.awsConfig.credentialsGenerator != null then
                    settings.awsConfig.credentialsGenerator
                  else
                    "aws-${instanceName}"
                }/credentials" 2>/dev/null)"; then
                  # Create temporary credentials file
                  AWS_CREDS_FILE=$(mktemp)
                  echo "$AWS_CREDENTIALS" > "$AWS_CREDS_FILE"
                  export AWS_SHARED_CREDENTIALS_FILE="$AWS_CREDS_FILE"
                  export AWS_DEFAULT_REGION="${settings.awsConfig.region}"
                  echo "✓ AWS credentials loaded from clan vars"
                else
                  echo "⚠ AWS credentials not found in clan vars"
                  echo "  Run: clan vars set $MACHINE_NAME ${
                    if settings.awsConfig.credentialsGenerator != null then
                      settings.awsConfig.credentialsGenerator
                    else
                      "aws-${instanceName}"
                  }/credentials <CREDENTIALS_FILE_CONTENT>"
                fi
              ''}

              # Source additional environment files
              ${lib.concatMapStringsSep "\n" (file: ''
                if [ -r "${file}" ]; then
                  source "${file}"
                  echo "✓ Sourced environment file: ${file}"
                fi
              '') settings.environmentFiles}

              echo ""
            '';

            # Helper functions script
            helperFunctionsScript = ''
              # Terraform helper functions
              tf() {
                ${terraform}/bin/${if settings.provider == "opentofu" then "tofu" else "terraform"} "$@"
              }

              tf-init() {
                echo "Initializing Terraform..."
                ${settings.preInitHooks}
                tf init
                ${settings.postInitHooks}
              }

              tf-plan() {
                echo "Planning Terraform changes..."
                tf plan -out=tfplan
              }

              tf-apply() {
                if [ -f tfplan ]; then
                  echo "Applying planned changes..."
                  tf apply tfplan
                else
                  echo "No plan file found. Run tf-plan first or use 'tf apply' directly."
                fi
              }

              tf-destroy() {
                echo "WARNING: This will destroy all managed infrastructure!"
                read -p "Are you sure? (yes/no): " confirm
                if [ "$confirm" = "yes" ]; then
                  tf destroy
                else
                  echo "Destruction cancelled."
                fi
              }

              terranix-build() {
                echo "Building Terraform configuration from Terranix..."
                if [ -f config.nix ]; then
                  terranix | tee config.tf.json
                  echo "✓ Generated config.tf.json"
                else
                  echo "✗ No config.nix found in current directory"
                fi
              }

              terranix-validate() {
                echo "Validating Terranix configuration..."
                terranix-build && tf validate
              }

              tf-workspace() {
                local cmd="$1"
                shift
                case "$cmd" in
                  list)
                    tf workspace list
                    ;;
                  new)
                    tf workspace new "$@"
                    ;;
                  select)
                    tf workspace select "$@"
                    ;;
                  delete)
                    tf workspace delete "$@"
                    ;;
                  *)
                    echo "Usage: tf-workspace {list|new|select|delete} [args]"
                    ;;
                esac
              }

              infra-status() {
                echo "Infrastructure Status"
                echo "===================="
                echo "Provider: ${settings.provider}"
                echo "Backend: ${
                  if settings.s3Backend.enable then "S3 (${settings.s3Backend.endpoint})" else "local"
                }"
                echo "Working Dir: ${settings.workingDirectory}"
                echo ""

                if [ -d "${resolvedWorkingDirectory}/.terraform" ]; then
                  echo "Terraform Status:"
                  cd "${resolvedWorkingDirectory}"
                  tf workspace list
                  echo ""
                  tf state list 2>/dev/null | head -10 || echo "No state found"
                else
                  echo "Terraform not initialized in working directory"
                fi
              }
            '';

            # Build the shell hook
            devShellHook = ''
              echo "╔══════════════════════════════════════════════════════╗"
              echo "║        Terranix Infrastructure Devshell               ║"
              echo "╚══════════════════════════════════════════════════════╝"
              echo ""

              ${envSetupScript}
              ${credentialsScript}

              echo "Available Commands:"
              echo "==================="
              echo "Terraform:"
              echo "  tf           - Terraform/OpenTofu CLI (${settings.provider})"
              echo "  tf-init      - Initialize Terraform"
              echo "  tf-plan      - Create execution plan"
              echo "  tf-apply     - Apply changes"
              echo "  tf-destroy   - Destroy infrastructure"
              echo "  tf-workspace - Manage workspaces"
              echo ""
              echo "Terranix:"
              echo "  terranix-build    - Build Terraform JSON from Nix"
              echo "  terranix-validate - Validate Terranix configuration"
              echo ""
              echo "Status:"
              echo "  infra-status - Show infrastructure status"
              echo ""
              echo "Cloud CLIs:"
              ${lib.optionalString (builtins.elem "cloudflare" settings.cloudProviders) ''
                echo "  cloudflared - Cloudflare tunnel CLI"
              ''}
              ${lib.optionalString (builtins.elem "aws" settings.cloudProviders) ''
                echo "  aws - AWS CLI"
              ''}
              echo ""
              echo "Working directory: ${settings.workingDirectory}"
              echo ""

              # Define helper functions
              ${helperFunctionsScript}

              # Change to working directory
              cd "${resolvedWorkingDirectory}" 2>/dev/null || echo "Note: Working directory doesn't exist yet"
            '';

            # Entry script for the devshell
            devShellScript = pkgs.writeShellScriptBin "terranix-devshell" ''
              #!/usr/bin/env bash
              echo "Entering Terranix infrastructure devshell..."

              # Create a temporary init file
              INIT_FILE=$(mktemp)
              cat > "$INIT_FILE" <<'EOF'
              # Source the default bashrc
              [ -f ~/.bashrc ] && source ~/.bashrc

              # Setup PATH
              export PATH="${lib.makeBinPath devShellPackages}:$PATH"

              # Run the shell hook
              ${devShellHook}
              EOF

              # Start bash with our init file
              ${pkgs.bash}/bin/bash --init-file "$INIT_FILE"

              # Cleanup
              rm -f "$INIT_FILE"
            '';

            # Terraform init script
            tfInitScript = pkgs.writeShellScriptBin "terranix-init" ''
                            #!/usr/bin/env bash
                            set -euo pipefail

                            # Find git repo root (fail if not in a git repo)
                            export GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (echo "Error: Not in a git repository" >&2; exit 1))"

                            echo "Initializing Terranix infrastructure directory..."

                            mkdir -p "${resolvedWorkingDirectory}"
                            cd "${resolvedWorkingDirectory}"

                            # Create a basic Terranix configuration if it doesn't exist
                            if [ ! -f config.nix ]; then
                              cat > config.nix <<EOF
                            { config, lib, pkgs, ... }:
                            {
                              terraform.required_version = ">= 1.0";

                              terraform.required_providers = {
                                ${lib.optionalString (builtins.elem "cloudflare" settings.cloudProviders) ''
                                  cloudflare = {
                                    source = "cloudflare/cloudflare";
                                    version = "~> 4.0";
                                  };
                                ''}
                              };

                              # Backend configured via backend.tf for S3

                              # Add your infrastructure resources here
                            }
              EOF
                              echo "✓ Created config.nix template"
                            fi

                            # Create standard .gitignore
                            if [ ! -f .gitignore ]; then
                              cat > .gitignore <<EOF
              # Terraform files
              *.tfplan
              tfplan
              .terraform/
              terraform.tfstate*
              crash.log
              override.tf
              override.tf.json
              *_override.tf
              *_override.tf.json
              .terraformrc
              terraform.rc

              # Backend config (contains credentials)
              backend.tf

              # Terranix
              config.tf.json
              EOF
                              echo "✓ Created .gitignore"
                            fi

                            echo ""
                            echo "Infrastructure directory initialized at ${settings.workingDirectory}"
                            echo "Run 'terranix-devshell' to enter the development environment"
            '';

            # Simplified tfx wrapper using systemd credentials
            terranixOneShotScript = ''
                            #!/usr/bin/env bash
                            set -euo pipefail

                            # Find git repo root
                            export GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "/home/$USER")"

                            # Configuration
                            WORKING_DIR="${resolvedWorkingDirectory}"
                            TERRAFORM="${terraform}/bin/${
                              if settings.provider == "opentofu" then "tofu" else "terraform"
                            }"
                            TERRANIX="${pkgs.terranix}/bin/terranix"
                            # Parse command line
                            CONFIG_FILE="config.nix"
                            COMMAND=""
                            ARGS=()

                            while [[ $# -gt 0 ]]; do
                              case "$1" in
                                --config|-c)
                                  CONFIG_FILE="$2"
                                  shift 2
                                  ;;
                                -*)
                                  ARGS+=("$1")
                                  shift
                                  ;;
                                *)
                                  if [ -z "$COMMAND" ]; then
                                    COMMAND="$1"
                                  else
                                    ARGS+=("$1")
                                  fi
                                  shift
                                  ;;
                              esac
                            done

                            COMMAND="''${COMMAND:-help}"

                            # Load credentials from systemd credentials directory
                            load_credentials() {
                              # Get machine hostname for clan vars
                              MACHINE_NAME="$(hostname)"

                              echo "Loading credentials from clan vars for machine: $MACHINE_NAME"

                              ${lib.optionalString settings.s3Backend.enable ''
                                # Load S3 credentials from clan vars
                                echo "Loading S3 credentials..."
                                if AWS_ACCESS_KEY_ID="$(clan vars get "$MACHINE_NAME" "${
                                  if settings.s3Backend.credentialsGenerator != null then
                                    settings.s3Backend.credentialsGenerator
                                  else
                                    "garage-terraform-terraform-state"
                                }/s3_access_key" 2>/dev/null)" && \
                                   AWS_SECRET_ACCESS_KEY="$(clan vars get "$MACHINE_NAME" "${
                                     if settings.s3Backend.credentialsGenerator != null then
                                       settings.s3Backend.credentialsGenerator
                                     else
                                       "garage-terraform-terraform-state"
                                   }/s3_secret_key" 2>/dev/null)"; then
                                  export AWS_ACCESS_KEY_ID
                                  export AWS_SECRET_ACCESS_KEY
                                  export AWS_ENDPOINT_URL_S3="${settings.s3Backend.endpoint}"
                                  export AWS_DEFAULT_REGION="${settings.s3Backend.region}"
                                  echo "✓ S3 credentials loaded from clan vars"
                                else
                                  echo "⚠️  Warning: S3 credentials not found in clan vars"
                                  echo "  Run: clan vars set $MACHINE_NAME ${
                                    if settings.s3Backend.credentialsGenerator != null then
                                      settings.s3Backend.credentialsGenerator
                                    else
                                      "garage-terraform-terraform-state"
                                  }/s3_access_key <ACCESS_KEY>"
                                  echo "  Run: clan vars set $MACHINE_NAME ${
                                    if settings.s3Backend.credentialsGenerator != null then
                                      settings.s3Backend.credentialsGenerator
                                    else
                                      "garage-terraform-terraform-state"
                                  }/s3_secret_key <SECRET_KEY>"
                                  return 1
                                fi
                              ''}

                              ${lib.optionalString (builtins.elem "cloudflare" settings.cloudProviders) ''
                                # Load Cloudflare credentials from clan vars
                                echo "Loading Cloudflare credentials..."
                                if CLOUDFLARE_API_TOKEN="$(clan vars get "$MACHINE_NAME" "${
                                  if settings.cloudflareConfig.apiTokenGenerator != null then
                                    settings.cloudflareConfig.apiTokenGenerator
                                  else
                                    "cloudflare-${instanceName}"
                                }/${settings.cloudflareConfig.apiTokenFile}" 2>/dev/null)"; then
                                  export CLOUDFLARE_API_TOKEN
                                  echo "✓ Cloudflare API token loaded from clan vars"
                                else
                                  echo "⚠️  Warning: Cloudflare API token not found in clan vars"
                                  echo "  Run: clan vars set $MACHINE_NAME ${
                                    if settings.cloudflareConfig.apiTokenGenerator != null then
                                      settings.cloudflareConfig.apiTokenGenerator
                                    else
                                      "cloudflare-${instanceName}"
                                  }/${settings.cloudflareConfig.apiTokenFile} <API_TOKEN>"
                                fi
                              ''}

                              ${lib.optionalString (builtins.elem "aws" settings.cloudProviders) ''
                                # Load AWS credentials from clan vars
                                echo "Loading AWS credentials..."
                                if AWS_CREDENTIALS="$(clan vars get "$MACHINE_NAME" "${
                                  if settings.awsConfig.credentialsGenerator != null then
                                    settings.awsConfig.credentialsGenerator
                                  else
                                    "aws-${instanceName}"
                                }/credentials" 2>/dev/null)"; then
                                  # Create temporary credentials file
                                  AWS_CREDS_FILE=$(mktemp)
                                  echo "$AWS_CREDENTIALS" > "$AWS_CREDS_FILE"
                                  export AWS_SHARED_CREDENTIALS_FILE="$AWS_CREDS_FILE"
                                  export AWS_DEFAULT_REGION="${settings.awsConfig.region}"
                                  echo "✓ AWS credentials loaded from clan vars"
                                else
                                  echo "⚠️  Warning: AWS credentials not found in clan vars"
                                  echo "  Run: clan vars set $MACHINE_NAME ${
                                    if settings.awsConfig.credentialsGenerator != null then
                                      settings.awsConfig.credentialsGenerator
                                    else
                                      "aws-${instanceName}"
                                  }/credentials <CREDENTIALS_FILE_CONTENT>"
                                fi
                              ''}
                            }

                            # Execute command with credentials
                            case "$COMMAND" in
                              init)
                                echo "🚀 Initializing Terraform..."
                                mkdir -p "$WORKING_DIR"
                                cd "$WORKING_DIR"

                                load_credentials || exit 1

                                ${lib.optionalString settings.s3Backend.enable ''
                                                      # Generate backend.tf
                                                      cat > backend.tf <<'EOBKND'
                                  terraform {
                                    backend "s3" {
                                      bucket = "${settings.s3Backend.bucket}"
                                      key    = "${instanceName}/terraform.tfstate"
                                      endpoint = "http://${settings.s3Backend.endpoint}"

                                      region = "${settings.s3Backend.region}"
                                      skip_credentials_validation = true
                                      skip_metadata_api_check = true
                                      skip_region_validation = true
                                      use_path_style = true

                                      encrypt = true
                                    }
                                  }
                                  EOBKND
                                                      echo '✓ Generated backend.tf for S3 state'
                                ''}

                                if [ ! -f config.nix ]; then
                                  cat > config.nix <<'EOCONF'
              { ... }:
              {
                terraform.required_version = ">= 1.0";
                # Add your infrastructure here
              }
              EOCONF
                                  echo '✓ Created config.nix template'
                                fi

                                $TERRAFORM init
                                echo '✓ Terraform initialized'
                                ;;

                              plan)
                                echo "📋 Creating execution plan..."
                                cd "$WORKING_DIR"

                                load_credentials || exit 1

                                if [ -f "$CONFIG_FILE" ]; then
                                  $TERRANIX "$CONFIG_FILE" > config.tf.json
                                  echo '✓ Generated config.tf.json from Terranix'
                                fi
                                $TERRAFORM plan -out=tfplan "''${ARGS[@]}"
                                ;;

                              apply)
                                echo "🚀 Applying changes..."
                                cd "$WORKING_DIR"

                                load_credentials || exit 1

                                if [ -f tfplan ]; then
                                  $TERRAFORM apply tfplan
                                else
                                  if [ -f "$CONFIG_FILE" ]; then
                                    $TERRANIX "$CONFIG_FILE" > config.tf.json
                                    echo '✓ Generated config.tf.json from Terranix'
                                  fi
                                  $TERRAFORM apply -auto-approve "''${ARGS[@]}"
                                fi
                                ;;

                              destroy)
                                echo "💥 Destroying infrastructure..."
                                echo "⚠️  This will destroy all managed infrastructure!"
                                read -p "Type 'yes' to confirm: " confirm

                                if [ "$confirm" = "yes" ]; then
                                  cd "$WORKING_DIR"
                                  load_credentials || exit 1

                                  if [ -f "$CONFIG_FILE" ]; then
                                    $TERRANIX "$CONFIG_FILE" > config.tf.json
                                    echo '✓ Generated config.tf.json from Terranix'
                                  fi
                                  $TERRAFORM destroy -auto-approve "''${ARGS[@]}"
                                else
                                  echo "Destruction cancelled"
                                fi
                                ;;

                              state|output|refresh|import|validate)
                                cd "$WORKING_DIR"
                                load_credentials || exit 1
                                $TERRAFORM "$COMMAND" "''${ARGS[@]}"
                                ;;

                              build)
                                echo "🔨 Building Terraform JSON from Terranix..."
                                cd "$WORKING_DIR"
                                if [ -f "$CONFIG_FILE" ]; then
                                  $TERRANIX "$CONFIG_FILE" | tee config.tf.json
                                  echo "✓ Generated config.tf.json"
                                else
                                  echo "Error: $CONFIG_FILE not found"
                                  exit 1
                                fi
                                ;;

                              help|--help|-h)
                                cat <<EOFHELP
              Terranix Infrastructure Management (${instanceName})

              Usage: tfx [--config FILE] <command> [args]

              Commands:
                init        Initialize Terraform
                plan        Create execution plan
                apply       Apply infrastructure changes
                destroy     Destroy infrastructure

                build       Build Terraform JSON from Terranix
                validate    Validate configuration

                state       Manage Terraform state
                output      Show outputs
                refresh     Refresh state
                import      Import existing resources

              All commands use systemd credentials for secure access.
              State is encrypted via Clan vars.

              Working Directory: $WORKING_DIR
              Provider: ${settings.provider}
              EOFHELP
                                ;;

                              *)
                                echo "Unknown command: $COMMAND"
                                echo "Run 'tfx help' for available commands"
                                exit 1
                                ;;
                            esac
            '';

          in
          lib.mkIf settings.enable {
            # Restore systemd service for credential loading
            systemd.services."terranix-${instanceName}-credentials" = {
              description = "Terranix credentials holder for ${instanceName}";
              serviceConfig = {
                Type = "simple";
                Restart = "always";
                RestartSec = 10;
                LoadCredential = lib.flatten [
                  (lib.optionals settings.s3Backend.enable [
                    "s3_access_key:${config.clan.core.vars.generators.${s3GeneratorName}.files.s3_access_key.path}"
                    "s3_secret_key:${config.clan.core.vars.generators.${s3GeneratorName}.files.s3_secret_key.path}"
                  ])
                  (lib.optionals (builtins.elem "cloudflare" settings.cloudProviders) [
                    "cloudflare_token:${
                      config.clan.core.vars.generators.${
                        if settings.cloudflareConfig.apiTokenGenerator != null then
                          settings.cloudflareConfig.apiTokenGenerator
                        else
                          "cloudflare-${instanceName}"
                      }.files.${settings.cloudflareConfig.apiTokenFile}.path
                    }"
                  ])
                  (lib.optionals (builtins.elem "aws" settings.cloudProviders) [
                    "aws_credentials:${
                      config.clan.core.vars.generators.${
                        if settings.awsConfig.credentialsGenerator != null then
                          settings.awsConfig.credentialsGenerator
                        else
                          "aws-${instanceName}"
                      }.files.credentials.path
                    }"
                  ])
                ];
                Environment = lib.flatten [
                  "TERRANIX_ALLOW_WORLD_READABLE_SECRETS=true"
                  (lib.optionals settings.s3Backend.enable [
                    "AWS_ACCESS_KEY_ID_FILE=%d/s3_access_key"
                    "AWS_SECRET_ACCESS_KEY_FILE=%d/s3_secret_key"
                  ])
                  (lib.optionals (builtins.elem "cloudflare" settings.cloudProviders) [
                    "CLOUDFLARE_API_TOKEN_FILE=%d/cloudflare_token"
                  ])
                  (lib.optionals (builtins.elem "aws" settings.cloudProviders) [
                    "AWS_SHARED_CREDENTIALS_FILE=%d/aws_credentials"
                  ])
                ];
                ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
              };
              wantedBy = [ "multi-user.target" ];
            };

            # Install the scripts
            environment.systemPackages = [
              devShellScript
              tfInitScript
              (pkgs.writeShellScriptBin "tfx" terranixOneShotScript)
            ];

            # Enhanced Clan generators with shared/instance-specific pattern
            clan.core.vars.generators = lib.mkMerge [
              # S3 backend credentials generator (instance-specific)
              (lib.mkIf (settings.s3Backend.enable && settings.s3Backend.credentialsGenerator == null) {
                "${s3GeneratorName}" = {
                  files.s3_access_key = {
                    secret = false;
                  };
                  files.s3_secret_key = {
                    secret = true;
                  };
                  prompts = {
                    s3_access_key = {
                      description = "S3 Access Key for ${instanceName} Terraform state";
                    };
                    s3_secret_key = {
                      description = "S3 Secret Key for ${instanceName} Terraform state";
                      type = "hidden";
                    };
                  };
                  script = ''
                    echo "$prompt_value_s3_access_key" > "$out"/s3_access_key
                    echo "$prompt_value_s3_secret_key" > "$out"/s3_secret_key
                  '';
                };
              })

              # Cloudflare provider generator (instance-specific by default)
              (lib.mkIf
                (
                  builtins.elem "cloudflare" settings.cloudProviders
                  && settings.cloudflareConfig.apiTokenGenerator == null
                )
                {
                  "cloudflare-${instanceName}" = {
                    files.api_token = {
                      secret = true;
                    };
                    prompts.api_token = {
                      description = "Enter Cloudflare API token for ${instanceName}";
                      type = "hidden";
                    };
                    script = ''
                      cat "$prompts/api_token" > "$out"/api_token
                    '';
                  };
                }
              )

              # AWS provider generator (instance-specific)
              (lib.mkIf
                (builtins.elem "aws" settings.cloudProviders && settings.awsConfig.credentialsGenerator == null)
                {
                  "aws-${instanceName}" = {
                    files.credentials = {
                      secret = true;
                    };
                    prompts = {
                      access_key_id = {
                        description = "AWS Access Key ID for ${instanceName}";
                      };
                      secret_access_key = {
                        description = "AWS Secret Access Key for ${instanceName}";
                        type = "hidden";
                      };
                    };
                    script = ''
                      cat > "$out"/credentials <<EOF
                      [default]
                      aws_access_key_id = $(cat "$prompts/access_key_id")
                      aws_secret_access_key = $(cat "$prompts/secret_access_key")
                      EOF
                    '';
                  };
                }
              )
            ];

            # Add activation script
            system.activationScripts."terranix-devshell-${instanceName}-info" = ''
              echo "Terranix infrastructure devshell '${instanceName}' is available."
              echo "Commands:"
              echo "  tfx              - One-shot command for infrastructure operations"
              echo "  terranix-init    - Initialize the infrastructure directory"
              echo "  terranix-devshell - Enter the infrastructure environment"
              echo ""
              echo "Systemd service: terranix-${instanceName}-credentials (loads credentials securely)"
              ${lib.optionalString settings.s3Backend.enable ''
                echo "S3 Backend: Enabled (${settings.s3Backend.endpoint})"
              ''}
              echo "Run 'tfx help' for available commands"
            '';
          };
      };
  };
}
