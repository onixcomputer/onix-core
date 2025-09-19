{ inputs, ... }:
{
  instances = {
    # Garage S3-compatible object store for Terraform state
    "terraform-state" = {
      module.name = "garage";
      module.input = "self";
      roles.server = {
        # Deploy to machines with 'garage-server' tag
        tags.garage-server = { };

        # All default settings work for single-node setup
        # S3 on port 3900, K2V on 3904, admin on 3903
        settings = { };
      };
    };
  };
}
