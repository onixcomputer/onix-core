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

              # Detect deployment approach (legacy vs integrated)
              INTEGRATED_MODE=false

              # Check if we have clan service instances with terraform enabled
              if command -v nix &>/dev/null; then
                KEYCLOAK_INSTANCES=$(nix eval --json .#nixosConfigurations --apply 'configs: builtins.mapAttrs (name: config: if config.config.clan.inventory.services.keycloak or {} != {} then "service" else "none") configs' 2>/dev/null | jq -r 'to_entries[] | select(.value == "service") | .key' 2>/dev/null || echo "")
                if [ -n "$KEYCLOAK_INSTANCES" ]; then
                  INTEGRATED_MODE=true
                fi
              fi

              # For legacy mode, change to cloud directory
              if [ "$INTEGRATED_MODE" = false ]; then
                cd cloud
              fi

              # Initialize terraform configuration based on mode
              if [ "$INTEGRATED_MODE" = true ]; then
                echo "🚀 Integrated mode detected - Using clan service terraform integration"
                echo "Keycloak instances with terraform: $KEYCLOAK_INSTANCES"
                echo ""

                # In integrated mode, terraform configs are managed by the service
                # We don't need to generate main.tf.json here
              else
                echo "🔧 Legacy mode - Using cloud/ directory terraform configuration"

                if [ ! -f main.tf.json ] || [ infrastructure.nix -nt main.tf.json ]; then
                  echo "Generating Terraform configuration..."
                  ${pkgs.terranix}/bin/terranix infrastructure.nix > main.tf.json
                fi

                if [ ! -d .terraform ]; then
                  echo "Initializing Terraform..."
                  ${pkgs.opentofu}/bin/tofu init
                fi

                # Load Keycloak admin password from clan vars
                echo "Loading Keycloak admin password from clan vars..."
                KEYCLOAK_ADMIN_PASSWORD=$(cd .. && clan vars get aspen1 keycloak-adeci/admin_password)
                if [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
                  echo "Error: Failed to load Keycloak admin password from clan vars"
                  echo "You may need to generate clan vars first: clan vars generate keycloak-adeci aspen1"
                  exit 1
                fi
                echo "Successfully loaded Keycloak admin password from clan vars"

                # Update terraform.tfvars with the actual password
                if [ -f terraform-admin-cli.tfvars ]; then
                  cp terraform-admin-cli.tfvars terraform.tfvars.tmp
                  echo "keycloak_admin_password = \"$KEYCLOAK_ADMIN_PASSWORD\"" >> terraform.tfvars.tmp
                  mv terraform.tfvars.tmp terraform.tfvars
                  echo "Updated terraform.tfvars with generated admin password"
                fi
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
                # Check if it's a Keycloak realm
                elif ${pkgs.jq}/bin/jq -e ".resource.keycloak_realm.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                  # Add the realm itself
                  targets="$targets -target=keycloak_realm.$resource"
                # Check if it's a Keycloak client
                elif ${pkgs.jq}/bin/jq -e ".resource.keycloak_openid_client.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                  # Add the client itself
                  targets="$targets -target=keycloak_openid_client.$resource"
                  # Add client-related resources if they exist
                  targets="$targets -target=keycloak_openid_client_authorization_settings.$resource"
                  targets="$targets -target=keycloak_openid_client_authorization_resource.$resource"
                  targets="$targets -target=keycloak_openid_client_authorization_scope.$resource"
                  targets="$targets -target=keycloak_openid_client_authorization_permission.$resource"
                  targets="$targets -target=keycloak_openid_client_default_scopes.$resource"
                  targets="$targets -target=keycloak_openid_client_optional_scopes.$resource"
                  targets="$targets -target=keycloak_openid_client_service_account_role.$resource"
                # Check if it's a Keycloak user
                elif ${pkgs.jq}/bin/jq -e ".resource.keycloak_user.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                  # Add the user itself
                  targets="$targets -target=keycloak_user.$resource"
                  # Add user-related resources if they exist
                  targets="$targets -target=keycloak_user_groups.$resource"
                  targets="$targets -target=keycloak_user_roles.$resource"
                # Check if it's a Keycloak group
                elif ${pkgs.jq}/bin/jq -e ".resource.keycloak_group.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                  # Add the group itself
                  targets="$targets -target=keycloak_group.$resource"
                  # Add group-related resources if they exist
                  targets="$targets -target=keycloak_group_memberships.$resource"
                  targets="$targets -target=keycloak_group_roles.$resource"
                # Check if it's a Keycloak role
                elif ${pkgs.jq}/bin/jq -e ".resource.keycloak_role.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                  # Add the role itself
                  targets="$targets -target=keycloak_role.$resource"
                fi

                echo "$targets"
              }

              build_keycloak_resource_targets() {
                local resource_type="$1"
                local resource="$2"
                local targets=""

                case "$resource_type" in
                  realm)
                    if ${pkgs.jq}/bin/jq -e ".resource.keycloak_realm.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                      targets="$targets -target=keycloak_realm.$resource"
                      # Include realm-level resources
                      targets="$targets -target=keycloak_realm_events.$resource"
                      targets="$targets -target=keycloak_realm_localization.$resource"
                    fi
                    ;;
                  client)
                    if ${pkgs.jq}/bin/jq -e ".resource.keycloak_openid_client.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                      targets="$targets -target=keycloak_openid_client.$resource"
                      # Include all client-related resources
                      for client_resource in authorization_settings authorization_resource authorization_scope authorization_permission default_scopes optional_scopes service_account_role; do
                        targets="$targets -target=keycloak_openid_client_$client_resource.$resource"
                      done
                    fi
                    ;;
                  user)
                    if ${pkgs.jq}/bin/jq -e ".resource.keycloak_user.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                      targets="$targets -target=keycloak_user.$resource"
                      targets="$targets -target=keycloak_user_groups.$resource"
                      targets="$targets -target=keycloak_user_roles.$resource"
                    fi
                    ;;
                  group)
                    if ${pkgs.jq}/bin/jq -e ".resource.keycloak_group.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                      targets="$targets -target=keycloak_group.$resource"
                      targets="$targets -target=keycloak_group_memberships.$resource"
                      targets="$targets -target=keycloak_group_roles.$resource"
                    fi
                    ;;
                  role)
                    if ${pkgs.jq}/bin/jq -e ".resource.keycloak_role.\"$resource\"" main.tf.json >/dev/null 2>&1; then
                      targets="$targets -target=keycloak_role.$resource"
                    fi
                    ;;
                esac

                echo "$targets"
              }

              is_valid_resource() {
                local resource="$1"
                if [ -f main.tf.json ]; then
                  ${pkgs.jq}/bin/jq -e ".resource.aws_instance.\"$resource\" // .resource.aws_s3_bucket.\"$resource\" // .resource.keycloak_realm.\"$resource\" // .resource.keycloak_openid_client.\"$resource\" // .resource.keycloak_user.\"$resource\" // .resource.keycloak_group.\"$resource\" // .resource.keycloak_role.\"$resource\" // false" main.tf.json >/dev/null 2>&1
                else
                  [[ "$resource" =~ ^(server|s3|realm|client|user|group|role)-[0-9_a-zA-Z-]+$ ]]
                fi
              }

              is_valid_keycloak_resource() {
                local resource_type="$1"
                local resource="$2"
                if [ -f main.tf.json ]; then
                  case "$resource_type" in
                    realm)
                      ${pkgs.jq}/bin/jq -e ".resource.keycloak_realm.\"$resource\"" main.tf.json >/dev/null 2>&1
                      ;;
                    client)
                      ${pkgs.jq}/bin/jq -e ".resource.keycloak_openid_client.\"$resource\"" main.tf.json >/dev/null 2>&1
                      ;;
                    user)
                      ${pkgs.jq}/bin/jq -e ".resource.keycloak_user.\"$resource\"" main.tf.json >/dev/null 2>&1
                      ;;
                    group)
                      ${pkgs.jq}/bin/jq -e ".resource.keycloak_group.\"$resource\"" main.tf.json >/dev/null 2>&1
                      ;;
                    role)
                      ${pkgs.jq}/bin/jq -e ".resource.keycloak_role.\"$resource\"" main.tf.json >/dev/null 2>&1
                      ;;
                    *)
                      return 1
                      ;;
                  esac
                else
                  return 1
                fi
              }

              list_resources() {
                if [ -f main.tf.json ]; then
                  local machines=$(${pkgs.jq}/bin/jq -r '.resource.aws_instance | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)
                  local buckets=$(${pkgs.jq}/bin/jq -r '.resource.aws_s3_bucket | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)
                  local realms=$(${pkgs.jq}/bin/jq -r '.resource.keycloak_realm | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)
                  local clients=$(${pkgs.jq}/bin/jq -r '.resource.keycloak_openid_client | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)
                  local users=$(${pkgs.jq}/bin/jq -r '.resource.keycloak_user | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)
                  local groups=$(${pkgs.jq}/bin/jq -r '.resource.keycloak_group | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)
                  local roles=$(${pkgs.jq}/bin/jq -r '.resource.keycloak_role | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)

                  local has_resources=false

                  if [ -n "$machines" ]; then
                    echo "AWS Machines: $machines"
                    has_resources=true
                  fi
                  if [ -n "$buckets" ]; then
                    echo "S3 Buckets: $buckets"
                    has_resources=true
                  fi
                  if [ -n "$realms" ]; then
                    echo "Keycloak Realms: $realms"
                    has_resources=true
                  fi
                  if [ -n "$clients" ]; then
                    echo "Keycloak Clients: $clients"
                    has_resources=true
                  fi
                  if [ -n "$users" ]; then
                    echo "Keycloak Users: $users"
                    has_resources=true
                  fi
                  if [ -n "$groups" ]; then
                    echo "Keycloak Groups: $groups"
                    has_resources=true
                  fi
                  if [ -n "$roles" ]; then
                    echo "Keycloak Roles: $roles"
                    has_resources=true
                  fi

                  if [ "$has_resources" = false ]; then
                    echo "No resources defined"
                  fi
                else
                  echo "Run 'cloud status' first to generate configuration"
                fi
              }

              show_keycloak_status() {
                local resource_type="$1"
                local resource="$2"

                if [ -n "$resource" ]; then
                  if is_valid_keycloak_resource "$resource_type" "$resource"; then
                    echo "Status for Keycloak $resource_type: $resource"
                    ${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "keycloak_$resource_type\.$resource\|keycloak_.*\.$resource" || echo "$resource_type $resource not found in state"
                    echo ""
                    echo "Outputs for $resource:"
                    ${pkgs.opentofu}/bin/tofu output -json 2>/dev/null | ${pkgs.jq}/bin/jq -r 'to_entries[] | select(.key | contains("'$resource'")) | "\(.key): \(.value.value)"' || echo "No outputs available"
                  else
                    echo "Error: Invalid Keycloak $resource_type '$resource'"
                    list_resources
                    exit 1
                  fi
                else
                  echo "Keycloak $resource_type status:"
                  case "$resource_type" in
                    realm)
                      ${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "keycloak_realm\." || echo "No Keycloak realms found"
                      ;;
                    client)
                      ${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "keycloak_openid_client\." || echo "No Keycloak clients found"
                      ;;
                    user)
                      ${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "keycloak_user\." || echo "No Keycloak users found"
                      ;;
                    group)
                      ${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "keycloak_group\." || echo "No Keycloak groups found"
                      ;;
                    role)
                      ${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "keycloak_role\." || echo "No Keycloak roles found"
                      ;;
                    *)
                      ${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "keycloak_" || echo "No Keycloak resources found"
                      ;;
                  esac
                fi
              }

              # Integrated mode functions
              find_keycloak_terraform_dirs() {
                # Find terraform directories for Keycloak instances on deployed machines
                local dirs=""
                for instance in $KEYCLOAK_INSTANCES; do
                  # Try to find the machine this instance is deployed to
                  local machine=$(nix eval --json .#nixosConfigurations.$instance.config.clan.inventory.services.keycloak --apply 'services: builtins.head (builtins.attrNames (builtins.head (builtins.attrValues services)).roles.server.machines)' 2>/dev/null || echo "")
                  if [ -n "$machine" ]; then
                    # Get the instance name from the service
                    local instance_name=$(nix eval --raw .#nixosConfigurations.$machine.config.clan.inventory.services.keycloak --apply 'services: builtins.head (builtins.attrNames services)' 2>/dev/null || echo "")
                    if [ -n "$instance_name" ]; then
                      local terraform_dir="/var/lib/keycloak-$instance_name-terraform"
                      # Note: In a real deployment, these would be on remote machines
                      # For now, we'll note the expected paths
                      dirs="$dirs $machine:$terraform_dir"
                    fi
                  fi
                done
                echo "$dirs"
              }

              run_integrated_keycloak_command() {
                local command="$1"
                local instance="$2"
                local extra_args="''${3:-}"

                if [ -z "$instance" ]; then
                  echo "Error: Instance name required for integrated mode"
                  echo "Available instances: $KEYCLOAK_INSTANCES"
                  return 1
                fi

                # Find the machine for this instance
                local machine=$(echo "$KEYCLOAK_INSTANCES" | tr ' ' '\n' | grep "^$instance$" | head -1)
                if [ -z "$machine" ]; then
                  echo "Error: Instance '$instance' not found in Keycloak instances"
                  echo "Available instances: $KEYCLOAK_INSTANCES"
                  return 1
                fi

                local terraform_dir="/var/lib/keycloak-$instance-terraform"

                case "$command" in
                  status)
                    echo "🔍 Checking Keycloak instance: $instance on machine: $machine"
                    echo "📁 Terraform directory: $terraform_dir"
                    echo ""
                    echo "To check actual status, SSH to the machine and run:"
                    echo "  ssh $machine"
                    echo "  cd $terraform_dir"
                    echo "  ./manage.sh status"
                    echo ""
                    echo "Service status (via clan):"
                    if command -v clan &>/dev/null; then
                      clan machines show $machine | grep -A5 -B5 keycloak || echo "No keycloak service info found"
                    else
                      echo "clan command not available"
                    fi
                    ;;
                  deploy)
                    echo "🚀 Deploying Keycloak service and terraform configuration for: $instance"
                    echo ""
                    echo "Step 1: Deploy the clan service (includes terraform config generation)"
                    if command -v clan &>/dev/null; then
                      echo "Running: clan machines deploy $machine"
                      clan machines deploy $machine
                      echo ""
                      echo "✅ Service deployed successfully"
                    else
                      echo "clan command not available"
                      return 1
                    fi

                    echo ""
                    echo "Step 2: Apply terraform configuration"
                    echo "To complete the deployment, SSH to the machine and run:"
                    echo "  ssh $machine"
                    echo "  cd $terraform_dir"
                    echo "  ./manage.sh init && ./manage.sh apply"
                    ;;
                  terraform)
                    echo "🔧 Terraform operations for instance: $instance"
                    echo ""
                    echo "To run terraform commands, SSH to the machine and use the management script:"
                    echo "  ssh $machine"
                    echo "  cd $terraform_dir"
                    echo "  ./manage.sh $extra_args"
                    echo ""
                    echo "Available terraform commands:"
                    echo "  ./manage.sh init     - Initialize terraform"
                    echo "  ./manage.sh plan     - Show planned changes"
                    echo "  ./manage.sh apply    - Apply changes"
                    echo "  ./manage.sh destroy  - Destroy resources"
                    echo "  ./manage.sh status   - Show current status"
                    echo "  ./manage.sh refresh  - Refresh variables from clan vars"
                    ;;
                  *)
                    echo "Error: Unknown command '$command'"
                    return 1
                    ;;
                esac
              }

              show_integrated_help() {
                echo "🚀 Integrated Keycloak Management (Clan Service Mode)"
                echo ""
                echo "Available instances: $KEYCLOAK_INSTANCES"
                echo ""
                echo "Usage: cloud keycloak-service <command> <instance> [args...]"
                echo ""
                echo "Commands:"
                echo "  status <instance>      - Show service and terraform status"
                echo "  deploy <instance>      - Deploy service and show terraform instructions"
                echo "  terraform <instance>   - Show terraform management instructions"
                echo ""
                echo "Examples:"
                echo "  cloud keycloak-service status keycloak-production"
                echo "  cloud keycloak-service deploy keycloak-production"
                echo "  cloud keycloak-service terraform keycloak-production"
                echo ""
                echo "For legacy terraform commands, use: cloud keycloak <command>"
                echo ""
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
                    ${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep -E "aws_instance|aws_s3_bucket|keycloak_" || echo "No resources created"
                    echo ""
                    echo "Outputs:"
                    # Get list of existing resources from state
                    existing_instances=$(${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "aws_instance\." | sed 's/aws_instance\.//' | tr '\n' '|' | sed 's/|$//')
                    existing_buckets=$(${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "aws_s3_bucket\." | grep -v "_versioning\|_public_access_block" | sed 's/aws_s3_bucket\.//' | tr '\n' '|' | sed 's/|$//')
                    existing_keycloak=$(${pkgs.opentofu}/bin/tofu state list 2>/dev/null | grep "keycloak_" | sed 's/keycloak_[^.]*\.//' | tr '\n' '|' | sed 's/|$//')

                    if [ -n "$existing_instances" ] || [ -n "$existing_buckets" ] || [ -n "$existing_keycloak" ]; then
                      all_outputs=$(${pkgs.opentofu}/bin/tofu output -json 2>/dev/null)
                      if [ -n "$all_outputs" ]; then
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

                          # Check against existing Keycloak resources
                          if [ "$should_show" = false ] && [ -n "$existing_keycloak" ]; then
                            for kc_resource in $(echo "$existing_keycloak" | tr '|' ' '); do
                              if echo "$output_key" | grep -q "$kc_resource"; then
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

                keycloak-service)
                  if [ "$INTEGRATED_MODE" = true ]; then
                    case "$2" in
                      status|deploy|terraform)
                        run_integrated_keycloak_command "$2" "$3" "$4"
                        ;;
                      *)
                        show_integrated_help
                        ;;
                    esac
                  else
                    echo "❌ Integrated mode not detected"
                    echo "This command requires clan service instances with terraform enabled"
                    echo "Use 'cloud keycloak' for legacy terraform management"
                  fi
                  ;;

                keycloak)
                  if [ "$INTEGRATED_MODE" = true ]; then
                    echo "🚀 Integrated mode detected - Use 'cloud keycloak-service' for service management"
                    echo "Or use legacy commands below for manual terraform operations"
                    echo ""
                  fi

                  case "$2" in
                    create)
                      if [ -n "$3" ] && [ -n "$4" ]; then
                        resource_type="$3"
                        resource_name="$4"
                        if is_valid_keycloak_resource "$resource_type" "$resource_name"; then
                          resource_targets=$(build_keycloak_resource_targets "$resource_type" "$resource_name")
                          echo "Creating Keycloak $resource_type: $resource_name and its associated resources..."
                          ${pkgs.opentofu}/bin/tofu apply $resource_targets -auto-approve
                        else
                          echo "Error: Invalid Keycloak $resource_type '$resource_name'"
                          list_resources
                          exit 1
                        fi
                      elif [ -n "$3" ]; then
                        resource_type="$3"
                        echo "Creating all Keycloak $resource_type resources..."
                        case "$resource_type" in
                          realm)
                            ${pkgs.opentofu}/bin/tofu apply -target=keycloak_realm -auto-approve
                            ;;
                          client)
                            ${pkgs.opentofu}/bin/tofu apply -target=keycloak_openid_client -auto-approve
                            ;;
                          user)
                            ${pkgs.opentofu}/bin/tofu apply -target=keycloak_user -auto-approve
                            ;;
                          group)
                            ${pkgs.opentofu}/bin/tofu apply -target=keycloak_group -auto-approve
                            ;;
                          role)
                            ${pkgs.opentofu}/bin/tofu apply -target=keycloak_role -auto-approve
                            ;;
                          *)
                            echo "Invalid Keycloak resource type. Use: realm, client, user, group, role"
                            exit 1
                            ;;
                        esac
                      else
                        echo "Creating all Keycloak resources..."
                        ${pkgs.opentofu}/bin/tofu apply -target=keycloak_realm -target=keycloak_openid_client -target=keycloak_user -target=keycloak_group -target=keycloak_role -auto-approve
                      fi
                      ;;

                    status)
                      if [ ! -f terraform.tfstate ]; then
                        echo "No infrastructure deployed yet"
                        exit 0
                      fi
                      resource_type="''${3:-all}"
                      resource_name="$4"
                      show_keycloak_status "$resource_type" "$resource_name"
                      ;;

                    destroy)
                      if [ -n "$3" ] && [ -n "$4" ]; then
                        resource_type="$3"
                        resource_name="$4"
                        if is_valid_keycloak_resource "$resource_type" "$resource_name"; then
                          resource_targets=$(build_keycloak_resource_targets "$resource_type" "$resource_name")
                          echo "Destroying Keycloak $resource_type: $resource_name and its associated resources..."
                          ${pkgs.opentofu}/bin/tofu destroy $resource_targets -auto-approve
                          echo "Refreshing state and outputs..."
                          ${pkgs.opentofu}/bin/tofu apply -refresh-only -auto-approve >/dev/null 2>&1
                        else
                          echo "Error: Invalid Keycloak $resource_type '$resource_name'"
                          list_resources
                          exit 1
                        fi
                      elif [ -n "$3" ]; then
                        resource_type="$3"
                        echo "Destroying all Keycloak $resource_type resources..."
                        case "$resource_type" in
                          realm)
                            ${pkgs.opentofu}/bin/tofu destroy -target=keycloak_realm -auto-approve
                            ;;
                          client)
                            ${pkgs.opentofu}/bin/tofu destroy -target=keycloak_openid_client -auto-approve
                            ;;
                          user)
                            ${pkgs.opentofu}/bin/tofu destroy -target=keycloak_user -auto-approve
                            ;;
                          group)
                            ${pkgs.opentofu}/bin/tofu destroy -target=keycloak_group -auto-approve
                            ;;
                          role)
                            ${pkgs.opentofu}/bin/tofu destroy -target=keycloak_role -auto-approve
                            ;;
                          *)
                            echo "Invalid Keycloak resource type. Use: realm, client, user, group, role"
                            exit 1
                            ;;
                        esac
                        echo "Refreshing state and outputs..."
                        ${pkgs.opentofu}/bin/tofu apply -refresh-only -auto-approve >/dev/null 2>&1
                      else
                        echo "Destroying all Keycloak resources..."
                        ${pkgs.opentofu}/bin/tofu destroy -target=keycloak_realm -target=keycloak_openid_client -target=keycloak_user -target=keycloak_group -target=keycloak_role -auto-approve
                        echo "Refreshing state and outputs..."
                        ${pkgs.opentofu}/bin/tofu apply -refresh-only -auto-approve >/dev/null 2>&1
                      fi
                      ;;

                    *)
                      echo "Keycloak Resource Management"
                      echo ""
                      echo "Usage: cloud keycloak <command> [resource_type] [resource_name]"
                      echo ""
                      echo "Commands:"
                      echo "  create [type] [name]  - Create Keycloak resources"
                      echo "  status [type] [name]  - Show Keycloak resource status"
                      echo "  destroy [type] [name] - Destroy Keycloak resources"
                      echo ""
                      echo "Resource Types:"
                      echo "  realm   - Keycloak realms"
                      echo "  client  - OpenID Connect clients"
                      echo "  user    - Users"
                      echo "  group   - User groups"
                      echo "  role    - Roles (realm and client roles)"
                      echo ""
                      echo "Examples:"
                      echo "  cloud keycloak create realm my-realm"
                      echo "  cloud keycloak status client my-client"
                      echo "  cloud keycloak destroy user john-doe"
                      echo "  cloud keycloak status realm"
                      echo ""
                      if [ -f main.tf.json ]; then
                        list_resources
                      fi
                      ;;
                  esac
                  ;;

                *)
                  echo "🌩️  Cloud Infrastructure Management"
                  echo ""

                  if [ "$INTEGRATED_MODE" = true ]; then
                    echo "🚀 Mode: Integrated (Clan Service + Terraform)"
                    echo "Available Keycloak instances: $KEYCLOAK_INSTANCES"
                    echo ""
                    echo "🔧 Integrated Commands:"
                    echo "  keycloak-service <cmd> <instance> - Manage clan service instances"
                    echo "    status <instance>              - Show service and terraform status"
                    echo "    deploy <instance>              - Deploy service and terraform config"
                    echo "    terraform <instance>           - Terraform management instructions"
                    echo ""
                    echo "Examples:"
                    echo "  cloud keycloak-service status keycloak-production"
                    echo "  cloud keycloak-service deploy keycloak-production"
                    echo ""
                    echo "🔧 Legacy Commands (still available):"
                  else
                    echo "🔧 Mode: Legacy (Cloud Directory + Terraform)"
                    echo ""
                    echo "Commands:"
                  fi

                  echo "  create [resource]     - Create all infrastructure or specific resource"
                  echo "  status [resource]     - Show infrastructure status (all or specific)"
                  echo "  destroy [resource]    - Destroy all infrastructure or specific resource"
                  echo "  keycloak <subcommand> - Manage Keycloak resources (see 'cloud keycloak' for details)"
                  echo ""

                  if [ "$INTEGRATED_MODE" = false ] && [ -f main.tf.json ]; then
                    list_resources
                    echo ""
                  fi

                  if [ "$INTEGRATED_MODE" = true ]; then
                    echo "💡 Tip: Use 'cloud keycloak-service' for integrated service management"
                    echo "💡 Tip: Use 'cloud keycloak' for manual terraform operations"
                  else
                    echo "💡 Tip: For integrated service management, configure clan service instances"
                    echo "💡 Tip: See modules/keycloak/examples/terraform-integration.nix for migration guide"
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
