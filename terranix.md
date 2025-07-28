# Terranix Integration Plan for Clan

## Overview

This document outlines the integration of Terranix (Terraform via Nix) into the Clan framework, leveraging Clan's inventory system for infrastructure as code management.

## Directory Structure

```
inventory/
├── services/
│   └── terranix.nix              # Terranix service configuration
├── infrastructure/               # Infrastructure definitions
│   ├── shared/                   # Shared infrastructure modules
│   │   ├── networking.nix        # VPCs, subnets
│   │   ├── security.nix          # Shared security groups
│   │   └── dns.nix              # Route53, DNS zones
│   ├── modules/                  # Reusable infrastructure templates
│   │   ├── ec2-with-sg.nix      # EC2 + Security Group template
│   │   ├── rds-cluster.nix       # RDS cluster template
│   │   └── s3-bucket.nix         # S3 bucket template
│   └── providers/                # Provider configurations
│       ├── aws.nix
│       └── hetzner.nix
└── tags/
    ├── aws-infra.nix            # Tag for AWS machines
    └── infra-manager.nix        # Tag for infrastructure managers

machines/
└── <machine-name>/
    ├── configuration.nix         # Standard Clan config
    └── infrastructure.nix        # Machine-specific infrastructure

terraform-state/                  # Git-tracked Terraform state
├── shared/
│   └── terraform.tfstate
└── machines/
    └── <machine-name>/
        └── terraform.tfstate

modules/
└── terranix/                    # Clan module for Terranix integration
    └── default.nix
```

## Implementation Plan

### Phase 1: Core Structure

1. **Create Terranix Clan Module** (`modules/terranix/default.nix`)
   - Hooks into Clan deployment lifecycle
   - Manages Terraform execution before NixOS deployment
   - Handles state management in git

2. **Define Infrastructure Layout** (`inventory/infrastructure/`)
   - Shared resources (VPCs, DNS zones)
   - Reusable modules/templates
   - Provider configurations

3. **Integrate with Flake** 
   - Add Terranix input
   - Define terranixConfigurations
   - Export terranixModules

### Phase 2: Service Integration

1. **Create Terranix Service** (`inventory/services/terranix.nix`)
   - Define roles for infrastructure management
   - Configure state backends
   - Set up dependency management

2. **Define Tags** 
   - `aws-infra`: Machines needing AWS resources
   - `infra-manager`: Machines managing shared infrastructure
   - `hetzner-infra`: Machines needing Hetzner resources

### Phase 3: Workflow Implementation

1. **Deployment Integration**
   - Auto-detect Terraform dependencies
   - Run Terraform before NixOS deployment
   - Handle state locking for concurrent deployments

2. **Helper Scripts**
   - `scripts/terraform.sh`: Manual Terraform operations
   - Integration with `clan machines install/update`

## Configuration Examples

### Shared Infrastructure
```nix
# inventory/infrastructure/shared/networking.nix
{
  resource.aws_vpc.main = {
    cidr_block = "10.0.0.0/16";
    tags.Name = "clan-main-vpc";
  };
  
  resource.aws_subnet.public = {
    vpc_id = "\${aws_vpc.main.id}";
    cidr_block = "10.0.1.0/24";
  };
  
  output.vpc_id = {
    value = "\${aws_vpc.main.id}";
  };
}
```

### Machine Infrastructure
```nix
# machines/web-server/infrastructure.nix
{ config, ... }:
{
  resource.aws_security_group.web = {
    name = "${config.networking.hostName}-sg";
    vpc_id = "\${data.terraform_remote_state.shared.outputs.vpc_id}";
    
    ingress = [{
      from_port = 80;
      to_port = 80;
      protocol = "tcp";
      cidr_blocks = ["0.0.0.0/0"];
    }];
  };
  
  resource.aws_instance.web = {
    ami = "ami-12345";
    instance_type = "t3.micro";
    subnet_id = "\${data.terraform_remote_state.shared.outputs.subnet_id}";
    vpc_security_group_ids = ["\${aws_security_group.web.id}"];
  };
}
```

### Machine Configuration
```nix
# machines/web-server/configuration.nix
{
  clanCore.tags = [ "aws-infra" ];
  
  clan.terranix = {
    enable = true;
    infrastructure = ./infrastructure.nix;
    dependsOn = [ "shared" ];
  };
}
```

## Deployment Workflow

### Automated (Future)
```bash
# Deploy new machine with infrastructure
clan machines install web-server
# 1. Detects Terranix is enabled
# 2. Checks/applies shared infrastructure
# 3. Creates machine-specific resources
# 4. Deploys NixOS to created infrastructure
```

### Manual (Initial Implementation)
```bash
# Deploy shared infrastructure
./scripts/terraform.sh shared apply

# Deploy machine infrastructure
./scripts/terraform.sh web-server apply

# Deploy NixOS
clan machines install web-server
```

## State Management

- Terraform state stored in git repository
- Simple file-based locking during operations
- Future: Integration with sops for state encryption
- State organized by workspace (shared/machines)

## Benefits

1. **Inventory-Centric**: Leverages Clan's existing patterns
2. **Flexible**: Supports shared and machine-specific infrastructure
3. **Git-Based**: Aligns with Clan's philosophy
4. **Scalable**: Grows with infrastructure needs
5. **Integrated**: Works with clan machines commands

## Next Steps

1. Create initial module structure
2. Implement basic Terranix service
3. Test with simple AWS deployment
4. Add dependency detection
5. Integrate with Clan deployment commands
6. Document patterns and best practices