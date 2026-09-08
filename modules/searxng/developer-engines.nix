let
  requestTimeoutSeconds = 10;
  optionCategories = [
    "it"
    "software wikis"
  ];
in
[
  {
    name = "github";
    engine = "github";
    shortcut = "gh";
    disabled = false;
  }
  {
    name = "nixos options";
    engine = "nix_options";
    option_source = "nixos";
    shortcut = "nixopts";
    categories = optionCategories;
    timeout = requestTimeoutSeconds;
    disabled = false;
  }
  {
    name = "home manager";
    engine = "nix_options";
    option_source = "home_manager";
    shortcut = "hm";
    categories = optionCategories;
    timeout = requestTimeoutSeconds;
    disabled = false;
  }
  {
    name = "noogle";
    engine = "noogle_catalog";
    shortcut = "noogle";
    categories = optionCategories;
    disabled = false;
  }
]
