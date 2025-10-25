# Terranix Utilities Module
_:

{
  # Utility to create terranix module from simple configuration
  mkTerranixModule =
    {
      # Terraform configuration blocks
      terraform ? { },
      providers ? { },
      variables ? { },
      resources ? { },
      outputs ? { },

      # Additional configuration
      extraConfig ? { },
    }:
    _:
    {
      inherit terraform;
      provider = providers;
      variable = variables;
      resource = resources;
      output = outputs;
    }
    // extraConfig;

  # Helper to convert legacy JSON configs to terranix modules
  jsonToTerranixModule =
    jsonFile: _:
    let
      jsonContent = builtins.fromJSON (builtins.readFile jsonFile);
    in
    jsonContent;

}
