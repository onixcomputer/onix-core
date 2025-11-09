{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      config,
      ...
    }:
    {
      devShells = {
        default = pkgs.mkShell {
          packages = [
            inputs.clan-core.packages.${system}.clan-cli
            config.pre-commit.settings.package
            config.packages.acl
            config.packages.vars
            config.packages.tags
            config.packages.roster
            pkgs.terranix
            pkgs.opentofu
            pkgs.awscli2
            pkgs.jq
            (pkgs.writeShellScriptBin "nix-prefetch-sri" ''
              if [ -z "$1" ]; then
                echo "Usage: nix-prefetch-sri <url>"
                exit 1
              fi
              ${pkgs.curl}/bin/curl -sL "$1" | ${pkgs.nix}/bin/nix hash file --sri /dev/stdin
            '')
            (pkgs.writeShellScriptBin "build" ''
              if [ -z "$1" ]; then
                echo "Usage: build <machine-name>"
                exit 1
              fi
              if command -v nom &> /dev/null; then
                nom build .#nixosConfigurations.$1.config.system.build.toplevel
              else
                nix build .#nixosConfigurations.$1.config.system.build.toplevel
              fi
            '')
            (pkgs.writeShellScriptBin "validate" ''
              echo "Running nix fmt..."
              nix fmt && echo "Running pre-commit checks..." && pre-commit run --all-files
            '')
            (pkgs.writeShellScriptBin "cloud" ''
              set -e

              cd cloud

              if [ ! -f main.tf.json ] || [ infrastructure.nix -nt main.tf.json ]; then
                echo "Generating Terraform configuration..."
                ${pkgs.terranix}/bin/terranix infrastructure.nix > main.tf.json
              fi

              if [ ! -d .terraform ]; then
                echo "Initializing Terraform..."
                ${pkgs.opentofu}/bin/tofu init
              fi

              build_resource_targets() {
                local resource="$1"
                local targets=""

                # Check if it's a machine (EC2 instance)
                if ${pkgs.jq}/bin/jq -e ".resource.aws_instance.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                  # Add the instance itself
                  targets="$targets -target=aws_instance.$resource"

                  # Add associated resources (these use hyphens now)
                  targets="$targets -target=aws_security_group.''${resource}-sg"
                  targets="$targets -target=aws_eip.''${resource}-eip"
                  targets="$targets -target=aws_eip_association.''${resource}-eip-assoc"
                # Check if it's an S3 bucket
                elif ${pkgs.jq}/bin/jq -e ".resource.aws_s3_bucket.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                  # Add the bucket and its related resources
                  targets="$targets -target=aws_s3_bucket.$resource"
                  targets="$targets -target=aws_s3_bucket_versioning.$resource"
                  targets="$targets -target=aws_s3_bucket_public_access_block.$resource"
                  # Add random_id if it's for this bucket
                  targets="$targets -target=random_id.''${resource}-suffix"
                fi

                echo "$targets"
              }

              is_valid_resource() {
                local resource="$1"
                if [ -f main.tf.json ]; then
                  ${pkgs.jq}/bin/jq -e ".resource.aws_instance.\"$resource\" // .resource.aws_s3_bucket.\"$resource\" // false" main.tf.json >/dev/null 2>&1
                else
                  [[ "$resource" =~ ^(server|s3)-[0-9_]+$ ]]
                fi
              }

              list_resources() {
                if [ -f main.tf.json ]; then
                  local machines=$(${pkgs.jq}/bin/jq -r '.resource.aws_instance | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)
                  local buckets=$(${pkgs.jq}/bin/jq -r '.resource.aws_s3_bucket | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)

                  if [ -n "$machines" ] && [ -n "$buckets" ]; then
                    echo "Machines: $machines"
                    echo "S3 Buckets: $buckets"
                  elif [ -n "$machines" ]; then
                    echo "Machines: $machines"
                  elif [ -n "$buckets" ]; then
                    echo "S3 Buckets: $buckets"
                  else
                    echo "No resources defined"
                  fi
                else
                  echo "Run 'cloud status' first to generate configuration"
                fi
              }

              case "$1" in
                create)
                  if [ -n "$2" ]; then
                    if is_valid_resource "$2"; then
                      resource_targets=$(build_resource_targets "$2")
                      echo "Creating $2 and its associated resources..."
                      ${pkgs.opentofu}/bin/tofu apply $resource_targets -auto-approve
                    else
                      echo "Error: Invalid resource name '$2'"
                      list_resources
                      exit 1
                    fi
                  else
                    echo "Creating all infrastructure..."
                    ${pkgs.opentofu}/bin/tofu apply -auto-approve
                  fi
                  ;;

                status)
                  if [ ! -f terraform.tfstate ]; then
                    echo "No infrastructure deployed yet"
                    exit 0
                  fi

                  if [ -n "$2" ]; then
                    if is_valid_resource "$2"; then
                      echo "Status for $2:"
                      ${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "$2" || echo "$2 not found"
                      echo ""
                      echo "Outputs for $2:"
                      ${pkgs.opentofu}/bin/tofu output -json 2>/dev/null | ${pkgs.jq}/bin/jq -r 'to_entries[] | select(.key | startswith("'$2'")) | "\(.key): \(.value.value)"' || echo "No outputs available"
                    else
                      echo "Error: Invalid resource name '$2'"
                      list_resources
                      exit 1
                    fi
                  else
                    echo "Infrastructure status:"
                    ${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep -E "aws_instance|aws_s3_bucket" || echo "No resources created"
                    echo ""
                    echo "Outputs:"
                    # Get list of existing instances and buckets from state
                    existing_instances=$(${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "aws_instance\." | sed 's/aws_instance\.//' | tr '\n' '|' | sed 's/|$//')
                    existing_buckets=$(${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "aws_s3_bucket\." | grep -v "_versioning\|_public_access_block" | sed 's/aws_s3_bucket\.//' | tr '\n' '|' | sed 's/|$//')

                    if [ -n "$existing_instances" ] || [ -n "$existing_buckets" ]; then
                      all_outputs=$(${pkgs.opentofu}/bin/tofu output -json 2>/dev/null)
                      if [ -n "$all_outputs" ]; then
                        filtered_outputs=""

                        # Filter outputs based on existing resources
                        while IFS= read -r line; do
                          output_key=$(echo "$line" | cut -d' ' -f1)

                          # Check if this output belongs to an existing resource
                          should_show=false

                          # Check against existing instances
                          if [ -n "$existing_instances" ]; then
                            for instance in $(echo "$existing_instances" | tr '|' ' '); do
                              if echo "$output_key" | grep -q "^$instance"; then
                                should_show=true
                                break
                              fi
                            done
                          fi

                          # Check against existing buckets
                          if [ "$should_show" = false ] && [ -n "$existing_buckets" ]; then
                            for bucket in $(echo "$existing_buckets" | tr '|' ' '); do
                              if echo "$output_key" | grep -q "^$bucket"; then
                                should_show=true
                                break
                              fi
                            done
                          fi

                          if [ "$should_show" = true ]; then
                            echo "$line"
                          fi
                        done < <(echo "$all_outputs" | ${pkgs.jq}/bin/jq -r 'to_entries[] | "\(.key) = \(.value.value)"')
                      fi
                    else
                      echo "No resources deployed"
                    fi
                  fi
                  ;;

                destroy)
                  if [ -n "$2" ]; then
                    if is_valid_resource "$2"; then
                      resource_targets=$(build_resource_targets "$2")
                      echo "Destroying $2 and its associated resources..."
                      ${pkgs.opentofu}/bin/tofu destroy $resource_targets -auto-approve
                      echo "Refreshing state and outputs..."
                      ${pkgs.opentofu}/bin/tofu apply -refresh-only -auto-approve >/dev/null 2>&1
                    else
                      echo "Error: Invalid resource name '$2'"
                      list_resources
                      exit 1
                    fi
                  else
                    echo "Destroying all infrastructure..."
                    ${pkgs.opentofu}/bin/tofu destroy -auto-approve
                    echo "Refreshing state and outputs..."
                    ${pkgs.opentofu}/bin/tofu apply -refresh-only -auto-approve >/dev/null 2>&1
                  fi
                  ;;

                *)
                  echo "Cloud Infrastructure Management"
                  echo ""
                  echo "Usage: cloud <command> [resource]"
                  echo ""
                  echo "Commands:"
                  echo "  create [resource]  - Create all infrastructure or specific resource"
                  echo "  status [resource]  - Show infrastructure status (all or specific)"
                  echo "  destroy [resource] - Destroy all infrastructure or specific resource"
                  echo ""
                  if [ -f main.tf.json ]; then
                    list_resources
                  fi
                  echo ""
                  ;;
              esac
            '')
          ];

          shellHook = ''
            echo "Clan Infrastructure Development Shell"
            echo "Available commands:"
            echo "  clan             - Clan CLI for infrastructure management"
            echo "  build            - Build a machine configuration (test locally)"
            echo "  cloud            - Cloud infrastructure management (create/status/destroy)"
            echo "  validate         - Run nix fmt and pre-commit checks"
            echo "  nix-prefetch-sri - Get SRI hash for a URL"
            echo ""
            echo "Analysis commands:"
            echo "  acl              - Analyze Clan secret ownership"
            echo "  vars             - Analyze Clan vars ownership"
            echo "  tags             - Analyze Clan machine tags"
            echo "  roster           - Analyze Clan user roster configurations"
            echo ""

            if [ -f .env ]; then
              echo "Loading AWS credentials..."
              set -a
              source .env
              set +a

              # Check if AWS credentials are actually set
              if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
                echo "  AWS credentials loaded."
                echo "  Cloud provisioning available."
              else
                echo "  .env file found but AWS credentials not set."
                echo "  Cloud provisioning unavailable."
              fi
            else
              echo "  No .env file found."
              echo "  Cloud provisioning unavailable."
            fi
            echo ""

            ${config.pre-commit.installationScript}
          '';
        };
      };
    };
}
