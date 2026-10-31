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
        on_aspen2 (
          (import "../instances/users.ncl")
          & (import "../instances/sshd.ncl")
          & (import "../instances/tailscale.ncl")
        )
        & { user-brittonr.roles.default.settings = brittonr }
        & (import "instances.ncl"),
  }
