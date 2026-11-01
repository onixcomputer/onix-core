# OnixOS systemd-host inventory: aspen2 as an OnixOS host (onixos.runtime =
# 'systemd_host) whose generation Mantle builds from pinned nixpkgs binaries.
#
# onixos/inventory.ncl keeps aspen2 a NixOS machine until its physical cutover; this
# inventory declares the same machine as an OnixOS host running the services it
# keeps. Dropped by decision: the Nix roles (nix-daemon, niks3, the gRPC build farm,
# the Nix signing key, fast-nix-gc, Nix CLI tools), the desktop stack (Xorg, LightDM,
# PipeWire, accounts-daemon) and heavy GUI/dev tools (Ghidra, KiCad, Emacs pgtk, ImHex,
# radare2, warp-terminal and similar).
#
#   onix build aspen2 --inventory onixos/host/inventory.ncl --lib <onixos>/lib \
#     --services <onixos>/modules --services onixos/services --json
fun onix =>
  let core = (import "../../inventory/core/machines.ncl").machines.aspen2 in
  # Tags whose NixOS files only serve dropped roles.
  let dropped_tags = ["boot-partition-gc", "minimal-docs", "remote-builders", "initrd-ssh"] in
  # The shared instance files select machines by tag (including the class-like
  # tag nixos); here every kept role is placed on aspen2 by name instead.
  let on_aspen2 = fun instances =>
    instances
    |> std.record.map (fun _instance definition =>
      std.record.update
        "roles"
        (
          definition.roles
          |> std.record.map (fun _role placement =>
            (std.record.remove "tags" placement) & { machines = ["aspen2"] }
          )
        )
        definition
    )
  in
  # This inventory declares one machine: a role that also names other machines is
  # narrowed to aspen2, and one that names none of them is dropped. Tags stay, so
  # tag-placed roles still reach aspen2.
  let only_aspen2 = fun instances =>
    instances
    |> std.record.map (fun _instance definition =>
      let roles =
        definition.roles
        |> std.record.map (fun _role placement =>
          if !(std.record.has_field "machines" placement) then
            placement
          else if std.typeof placement.machines == 'Record then
            let machines =
              placement.machines
              |> std.record.fields
              |> std.array.filter (fun machine => machine == "aspen2")
              |> std.array.map (fun machine => { field = machine, value = placement.machines."%{machine}" })
              |> std.record.from_array
            in
            if machines == {} then
              std.record.remove "machines" placement
            else
              std.record.update "machines" machines placement
          else
            let machines = placement.machines |> std.array.filter (fun machine => machine == "aspen2") in
            if machines == [] then
              std.record.remove "machines" placement
            else
              std.record.update "machines" machines placement
        )
        |> std.record.filter (fun _role placement =>
          std.record.has_field "machines" placement || std.record.has_field "tags" placement
        )
      in
      std.record.update "roles" roles definition
    )
  in
  # inventory/tags/common/shared-users.nix: brittonr's uid, group, shell and keys (the
  # nix-builder keys it also collects belong to the dropped build role).
  let brittonr = {
    uid = 1555,
    group = "brittonr",
    shell = "/run/current-system/sw/bin/fish",
    openssh.authorized_keys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework",
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAX7hNDY0L9JSSIP+NVTbDluJgJ9c/l9nzbuwCNkVxgr britton@cproof.ai",
    ],
  }
  in
  {
    machines
      | { _ : onix.Machine }
      | onix.NameMatchesKey
      = {
        aspen2 = {
          name = "aspen2",
          system = core.system,
          class = 'onixos,
          tags = core.tags |> std.array.filter (fun tag => !(std.array.elem tag dropped_tags)),
          addresses.lan = core.addresses.lan,
          deploy.targetHost = core.deploy.targetHost,
          age_public_key = (std.array.first (import "../../sops/machines/aspen2/key.json")).publickey,
          onixos = {
            runtime = 'systemd_host,
            host = {
              package_index = "aspen2-packages.json",
              secrets_dir = "../secrets",
            },
          },
        },
      },

    instances
      | { _ : onix.Instance }
      =
        # users, sshd and tailscale place roles by the class tag "nixos", which an
        # OnixOS host does not carry: those three are placed on aspen2 by name.
        on_aspen2 (
          (import "../instances/users.ncl")
          & (import "../instances/sshd.ncl")
          & (import "../instances/tailscale.ncl")
        )
        & only_aspen2 (
          (import "../instances/arxiv-corpus.ncl")
          & (import "../instances/berkeley-mono-font.ncl")
          & (import "../instances/borgbackup.ncl")
          & (import "../instances/grafana.ncl")
          & (import "../instances/home-manager-profiles.ncl")
          & (import "../instances/homepage-dashboard.ncl")
          & (import "../instances/laya.ncl")
          & (import "../instances/loki.ncl")
          & (import "../instances/mesh-llm.ncl")
          & (import "../instances/prometheus.ncl")
          & (import "../instances/music-assistant.ncl")
        )
        & { user-brittonr.roles.default.settings = brittonr }
        & (import "instances.ncl"),
  }
