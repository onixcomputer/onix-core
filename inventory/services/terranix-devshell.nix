_: {
  instances = {
    # Development environment infrastructure
    "infrastructure-dev" = {
      module.name = "terranix-devshell";
      module.input = "self";
      roles.deployer = {
        # Deploy to machines with 'infrastructure-dev' tag
        tags.infrastructure-dev = { };

        settings = {
          enable = true;
          provider = "opentofu";
          workingDirectory = "./infrastructure/dev";
          s3Backend = {
            enable = true;
            endpoint = "localhost:3900"; # Garage S3 API
            bucket = "terraform-state-dev";
            region = "garage"; # Garage region
            dynamoDbTable = "terraform-locks"; # For state locking
            credentialsGenerator = "garage-terraform-terraform-state"; # Use garage credentials
          };
          cloudProviders = [ "cloudflare" ];

          cloudflareConfig = {
            apiTokenGenerator = null; # Auto-generates as "cloudflare-infrastructure-dev"
            apiTokenFile = "api_token";
            email = null;
          };

          # Development environment specific hooks
          preInitHooks = ''
            echo "🔧 Development Environment"
            echo "Checking for existing dev state..."
            if [ -f .terraform/terraform.tfstate ]; then
              echo "Found existing dev state file"
            fi
          '';

          postInitHooks = ''
            echo "Development environment initialized"
            echo "Run 'tfx plan' to see what changes would be made"
          '';

        };
      };
    };

    # Staging environment infrastructure
    "infrastructure-staging" = {
      module.name = "terranix-devshell";
      module.input = "self";
      roles.deployer = {
        # Deploy to machines with 'infrastructure-staging' tag
        tags.infrastructure-staging = { };

        settings = {
          enable = true;
          provider = "opentofu";
          workingDirectory = "./infrastructure/staging";
          s3Backend = {
            enable = true;
            endpoint = "localhost:3900"; # Garage S3 API
            bucket = "terraform-state-staging";
            region = "garage"; # Garage region
            dynamoDbTable = "terraform-locks"; # For state locking
            credentialsGenerator = "garage-terraform-terraform-state"; # Use garage credentials
          };
          cloudProviders = [ "cloudflare" ];

          cloudflareConfig = {
            apiTokenGenerator = null; # Auto-generates as "cloudflare-infrastructure-dev"
            apiTokenFile = "api_token";
            email = null;
          };

          # Staging environment specific hooks
          preInitHooks = ''
            echo "🚧 Staging Environment"
            echo "Checking for existing staging state..."
            if [ -f .terraform/terraform.tfstate ]; then
              echo "Found existing staging state file"
            fi
          '';

          postInitHooks = ''
            echo "Staging environment initialized"
            echo "Run 'tfx-staging plan' to preview staging changes"
          '';

        };
      };
    };

    # Production environment infrastructure
    "infrastructure-prod" = {
      module.name = "terranix-devshell";
      module.input = "self";
      roles.deployer = {
        # Deploy to machines with 'infrastructure-prod' tag
        tags.infrastructure-prod = { };

        settings = {
          enable = true;
          provider = "opentofu";
          workingDirectory = "./infrastructure/prod";
          s3Backend = {
            enable = true;
            endpoint = "localhost:3900"; # Garage S3 API
            bucket = "terraform-state-prod";
            region = "garage"; # Garage region
            dynamoDbTable = "terraform-locks"; # For state locking
            credentialsGenerator = "garage-terraform-terraform-state"; # Use garage credentials
          };
          cloudProviders = [ "cloudflare" ];

          cloudflareConfig = {
            apiTokenGenerator = null; # Auto-generates as "cloudflare-infrastructure-dev"
            apiTokenFile = "api_token";
            email = null;
          };

          # Production environment specific hooks
          preInitHooks = ''
            echo "🚀 Production Environment"
            echo "⚠️  CAUTION: This is PRODUCTION infrastructure"
            echo "Checking for existing production state..."
            if [ -f .terraform/terraform.tfstate ]; then
              echo "Found existing production state file"
            fi
          '';

          postInitHooks = ''
            echo "Production environment initialized"
            echo "⚠️  Double-check all changes before applying to production"
            echo "Run 'tfx-prod plan' to preview production changes"
          '';

        };
      };
    };
  };
}
