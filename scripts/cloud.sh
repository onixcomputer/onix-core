#!/usr/bin/env bash
# Cloud Infrastructure Management Script
# Manages AWS infrastructure via OpenTofu/Terranix
set -e

cd cloud

# Generate Terraform configuration if needed
if [ ! -f main.tf.json ] || [ infrastructure.nix -nt main.tf.json ]; then
  echo "Generating Terraform configuration..."
  terranix infrastructure.nix > main.tf.json
fi

# Initialize Terraform if needed
if [ ! -d .terraform ]; then
  echo "Initializing Terraform..."
  tofu init
fi

build_resource_targets() {
  local resource="$1"
  local targets=""

  # Check if it's a machine (EC2 instance)
  if jq -e ".resource.aws_instance.\"$resource\"" main.tf.json >/dev/null 2>&1; then
    # Add the instance itself
    targets="$targets -target=aws_instance.$resource"

    # Add associated resources (these use hyphens now)
    targets="$targets -target=aws_security_group.${resource}-sg"
    targets="$targets -target=aws_eip.${resource}-eip"
    targets="$targets -target=aws_eip_association.${resource}-eip-assoc"
  # Check if it's an S3 bucket
  elif jq -e ".resource.aws_s3_bucket.\"$resource\"" main.tf.json >/dev/null 2>&1; then
    # Add the bucket and its related resources
    targets="$targets -target=aws_s3_bucket.$resource"
    targets="$targets -target=aws_s3_bucket_versioning.$resource"
    targets="$targets -target=aws_s3_bucket_public_access_block.$resource"
    # Add random_id if it's for this bucket
    targets="$targets -target=random_id.${resource}-suffix"
  fi

  echo "$targets"
}

is_valid_resource() {
  local resource="$1"
  if [ -f main.tf.json ]; then
    jq -e ".resource.aws_instance.\"$resource\" // .resource.aws_s3_bucket.\"$resource\" // false" main.tf.json >/dev/null 2>&1
  else
    [[ "$resource" =~ ^(server|s3)-[0-9_]+$ ]]
  fi
}

list_resources() {
  if [ -f main.tf.json ]; then
    local machines
    local buckets
    machines=$(jq -r '.resource.aws_instance | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)
    buckets=$(jq -r '.resource.aws_s3_bucket | keys[]' main.tf.json 2>/dev/null | paste -sd ', ' -)

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

show_status() {
  local resource="$1"

  if [ ! -f terraform.tfstate ]; then
    echo "No infrastructure deployed yet"
    exit 0
  fi

  if [ -n "$resource" ]; then
    if is_valid_resource "$resource"; then
      echo "Status for $resource:"
      tofu state list 2>/dev/null | grep "$resource" || echo "$resource not found"
      echo ""
      echo "Outputs for $resource:"
      tofu output -json 2>/dev/null | jq -r 'to_entries[] | select(.key | startswith("'"$resource"'")) | "\(.key): \(.value.value)"' || echo "No outputs available"
    else
      echo "Error: Invalid resource name '$resource'"
      list_resources
      exit 1
    fi
  else
    echo "Infrastructure status:"
    tofu state list 2>/dev/null | grep -E "aws_instance|aws_s3_bucket" || echo "No resources created"
    echo ""
    echo "Outputs:"
    # Get list of existing instances and buckets from state
    local existing_instances
    local existing_buckets
    existing_instances=$(tofu state list 2>/dev/null | grep "aws_instance\." | sed 's/aws_instance\.//' | tr '\n' '|' | sed 's/|$//')
    existing_buckets=$(tofu state list 2>/dev/null | grep "aws_s3_bucket\." | grep -v "_versioning\|_public_access_block" | sed 's/aws_s3_bucket\.//' | tr '\n' '|' | sed 's/|$//')

    if [ -n "$existing_instances" ] || [ -n "$existing_buckets" ]; then
      local all_outputs
      all_outputs=$(tofu output -json 2>/dev/null)
      if [ -n "$all_outputs" ]; then
        # Filter outputs based on existing resources
        while IFS= read -r line; do
          local output_key
          output_key=$(echo "$line" | cut -d' ' -f1)

          # Check if this output belongs to an existing resource
          local should_show=false

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
        done < <(echo "$all_outputs" | jq -r 'to_entries[] | "\(.key) = \(.value.value)"')
      fi
    else
      echo "No resources deployed"
    fi
  fi
}

case "$1" in
  create)
    if [ -n "$2" ]; then
      if is_valid_resource "$2"; then
        resource_targets=$(build_resource_targets "$2")
        echo "Creating $2 and its associated resources..."
        # shellcheck disable=SC2086
        tofu apply $resource_targets -auto-approve
      else
        echo "Error: Invalid resource name '$2'"
        list_resources
        exit 1
      fi
    else
      echo "Creating all infrastructure..."
      tofu apply -auto-approve
    fi
    ;;

  status)
    show_status "$2"
    ;;

  destroy)
    if [ -n "$2" ]; then
      if is_valid_resource "$2"; then
        resource_targets=$(build_resource_targets "$2")
        echo "Destroying $2 and its associated resources..."
        # shellcheck disable=SC2086
        tofu destroy $resource_targets -auto-approve
        echo "Refreshing state and outputs..."
        tofu apply -refresh-only -auto-approve >/dev/null 2>&1
      else
        echo "Error: Invalid resource name '$2'"
        list_resources
        exit 1
      fi
    else
      echo "Destroying all infrastructure..."
      tofu destroy -auto-approve
      echo "Refreshing state and outputs..."
      tofu apply -refresh-only -auto-approve >/dev/null 2>&1
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
