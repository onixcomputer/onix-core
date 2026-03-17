# Machine inventory contracts.
#
# Shared contract definitions for the machine registry.
# Imported by machines.ncl.
{
  # All valid machine tags.
  #
  # This is the single source of truth — a typo here fails at
  # `ncl export` time instead of silently producing a misconfigured machine.
  #
  # Tags fall into three categories:
  #   - Tag-file tags: have a corresponding inventory/tags/<name>.nix
  #   - Service tags:  consumed by inventory/services/ instances
  #   - Profile tags:  select home-manager profile sets (hm-laptop, hm-server)
  Tag = std.contract.from_validator (fun value =>
    let valid = [
      # --- tag-file tags (inventory/tags/*.nix) ---
      "amd-gpu",
      "audio",
      "cloud-hypervisor-host",
      "creative",
      "cross-compile",
      "desktop",
      "dev",
      "docker",
      "gaming",
      "greeter",
      "grub-theme",
      "initrd-ssh",
      "laptop",
      "laptop-input",
      "media",
      "minimal-docs",
      "nvidia",
      "openpgp",
      "password-manager",
      "perf-tuning",
      "pinenote",
      "remote-builders",
      "ssd-optimization",
      "taskwarrior",
      "typst",
      "udev-rules",
      "xdg-portal",

      # --- service instance tags ---
      "backup",
      "homepage-server",
      "llm",
      "llm-client",
      "monitoring",
      "prometheus",
      "static-demo",
      "static-test",
      "tailnet-brittonr",
      "traefik-blr",
      "traefik-desktop",

      # --- home-manager profile tags ---
      "hm-laptop",
      "hm-server",
    ]
    in
    if !(std.is_string value) then
      'Error { message = "tag must be a string, got %{std.typeof value}" }
    else if !(std.array.elem value valid) then
      'Error {
        message = "unknown tag: \"%{value}\"",
        notes = ["Check inventory/core/contracts.ncl for the list of valid tags."],
      }
    else
      'Ok
  ),

  Deploy = {
    targetHost
      | doc "SSH target, typically root@<hostname>"
      | String
      | std.string.NonEmpty,
    buildHost
      | doc "Remote build host (empty string = build locally)"
      | String,
  },

  Machine = {
    name
      | doc "Machine name — must match the attrset key"
      | String
      | std.string.NonEmpty,
    machineClass
      | doc "NixOS or nix-darwin"
      | std.enum.TagOrString
      | [| 'nixos, 'darwin |]
      | default = "nixos",
    tags
      | doc "Tags that select services, profiles, and tag-file configs"
      | Array Tag,
    deploy
      | doc "Deployment target and build delegation"
      | Deploy,
  },

  # Top-level inventory shape.
  Machines = {
    machines | { _ : Machine },
  },
}
