# Machine inventory contracts.
#
# Shared contract definitions for the machine registry.
# Imported by machines.ncl.

# --- Tag registry ---
#
# Single source of truth — a typo fails at `ncl export` time
# instead of silently producing a misconfigured machine.
let tag_file_tags = [
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
]
in

let service_tags = [
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
]
in

let profile_tags = ["hm-laptop", "hm-server"] in

let all_tags = std.array.flatten [tag_file_tags, service_tags, profile_tags] in

# --- Builder registry ---
#
# Maps remote-builder SSH hostnames to inventory machine names.
# Used by Nix (remote-builders.nix) to filter self from buildMachines,
# preventing infinite dispatch loops. If you add a machine as a nix
# build machine, it MUST appear here.
let builder_hosts = {
  "britton-air.local" = "britton-air",
  "iroh-aspen1" = "aspen1",
  "iroh-aspen2" = "aspen2",
  "britton-desktop" = "britton-desktop",
}
in

# --- Exported tag lists (consumed by Nix flake checks) ---
#
# `tagFileTags` lets the Nix-side tag-sync check verify that every
# registered tag has a .nix file and every tag .nix file is registered.
# `autoTagsWithFiles` lists auto-computed tags (e.g. "nixos") that have
# .nix files but aren't manually assigned to machines.

# --- Contracts ---
{
  tagFileTags = tag_file_tags,
  autoTagsWithFiles = ["nixos"],
  builderHosts = builder_hosts,
  Tag =
    std.contract.from_validator (match {
      value if std.is_string value && std.array.elem value all_tags => 'Ok,
      value if std.is_string value =>
        'Error {
          message = "unknown tag: \"%{value}\"",
          notes = ["Valid tags defined in contracts.ncl"],
        },
      _ => 'Error { message = "tag must be a string" },
    }
    ),

  SshHost =
    std.contract.from_validator (match {
      value if std.is_string value
        && std.string.is_match "^([a-zA-Z0-9._-]+@)?[a-zA-Z0-9._-]+$" value => 'Ok,
      value if std.is_string value =>
        'Error { message = "must be [user@]host, got \"%{value}\"" },
      _ => 'Error { message = "must be a string" },
    }
    ),

  System =
    let valid_systems = [
      "x86_64-linux",
      "aarch64-linux",
      "x86_64-darwin",
      "aarch64-darwin",
    ]
    in
    std.contract.from_validator (match {
      value if std.is_string value && std.array.elem value valid_systems => 'Ok,
      value if std.is_string value =>
        'Error {
          message = "unknown system: \"%{value}\"",
          notes = ["Valid: %{std.serialize 'Json valid_systems}"],
        },
      _ => 'Error { message = "system must be a string" },
    }
    ),

  Deploy = {
    targetHost | doc "SSH target (user@host)" | SshHost,
    buildHost | doc "Remote build host; omit to build locally" | SshHost | optional,
  },

  Machine = {
    system
      | doc "Nix system double (e.g. x86_64-linux, aarch64-darwin)"
      | System,
    machineClass
      | doc "NixOS or nix-darwin"
      | std.enum.TagOrString
      | [| 'nixos, 'darwin |]
      | default
      = "nixos",
    tags
      | doc "Tags selecting services, profiles, and tag configs"
      | Array Tag,
    deploy
      | doc "Deployment target and build delegation"
      | Deploy,
  },

  # Every builder SSH hostname must map to a real machine in the inventory,
  # and every machine with "remote-builders" tag that IS a builder target
  # must have a mapping entry. Without a mapping, the Nix self-filter can't
  # identify the machine and it dispatches builds to itself (infinite loop).
  NoSelfBuilder =
    std.contract.from_validator (fun machines =>
      let machine_names = std.record.fields machines in
      let builder_machine_names = std.record.values builder_hosts in
      let builder_ssh_hosts = std.record.fields builder_hosts in

      # Check 1: every builder target maps to a real machine
      let unknown_targets =
        builder_machine_names
        |> std.array.filter (fun name => !(std.array.elem name machine_names))
      in

      # Check 2: every machine with "remote-builders" tag that is also
      # a builder target has a mapping (so self-filter works)
      let unmapped_builders =
        std.record.to_array machines
        |> std.array.filter (fun { field, value } =>
          std.array.elem "remote-builders" value.tags
          && std.array.elem field builder_machine_names
        )
        |> std.array.map (fun { field, .. } => field)
        |> std.array.filter (fun name =>
          !(std.array.elem name builder_machine_names)
        )
      in

      if std.array.length unknown_targets > 0 then
        'Error {
          message = "builderHosts maps to unknown machine: \"%{std.array.first unknown_targets}\"",
          notes = [
            "Every value in builderHosts must be a machine name in the inventory.",
            "Either add the machine or remove the stale builderHosts entry.",
          ],
        }
      else if std.array.length unmapped_builders > 0 then
        'Error {
          message = "%{std.array.first unmapped_builders}: has remote-builders tag and is a builder target but missing from builderHosts",
          notes = [
            "Add a builderHosts entry mapping the SSH hostname to this machine.",
            "Without it, the machine will dispatch builds to itself (infinite loop).",
          ],
        }
      else
        'Ok
    ),

  NoConflictingProfiles =
    std.contract.from_validator (fun machines =>
      let profiles = ["hm-laptop", "hm-server"] in
      std.record.to_array machines
      |> std.array.map (fun { field, value } =>
        let hits =
          value.tags
          |> std.array.filter (fun t => std.array.elem t profiles)
        in
        if std.array.length hits > 1 then
          'Error { message = "%{field}: conflicting profiles %{std.serialize 'Json hits}" }
        else
          'Ok
      )
      |> std.array.filter (match { 'Error _ => true, _ => false })
      |> match {
        [] => 'Ok,
        [err, ..] => err,
      }
    ),

  # Top-level inventory shape.
  Machines = {
    machines | { _ : Machine } | NoConflictingProfiles | NoSelfBuilder,
  },
}
