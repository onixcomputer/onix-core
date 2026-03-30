# profilesBasePath is a Nix path (store copy) — stays in Nix.
{
  default = {
    username = { type = "string", description = "Username to configure home-manager for" },
    profiles = { type = "array_string", default = [], description = "Home-manager profile directories to load" },
  },
}
