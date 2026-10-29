# OnixOS inventory for onix-core.
#
# Machine facts come from inventory/core/machines.ncl, the source of truth
# shared with Clan. Every NixOS machine is declared so multi-machine services
# see the same peers they see under Clan, but only the machines in
# flake-outputs/onixos.nix `assembled` are built here; the rest stay on Clan.
#
# Instances live in onixos/instances/<service>.ncl, one file per service
# module in onixos/services/<service>.ncl.
fun onix =>
  let core = (import "../inventory/core/machines.ncl").machines in
  # machines.ncl defaults machineClass to the enum tag 'nixos.
  let is_nixos = fun m => m.machineClass == 'nixos in
  # Clan reads a bare deploy.buildHost as root@<host>.
  let ssh_target = fun host =>
    if std.string.contains "@" host then host else "root@%{host}"
  in
  let project = fun machine_name m =>
    {
      name = machine_name,
      system = m.system,
      tags = m.tags,
      deploy =
        (
          if std.record.has_field "deploy" m && std.record.has_field "targetHost" m.deploy then
            { targetHost = m.deploy.targetHost }
          else
            {}
        )
        & (
          if std.record.has_field "deploy" m && std.record.has_field "buildHost" m.deploy then
            { buildHost = ssh_target m.deploy.buildHost }
          else
            {}
        ),
      addresses =
        if std.record.has_field "addresses" m && std.record.has_field "lan" m.addresses then
          { lan = m.addresses.lan }
        else
          {},
    }
  in
  {
    build.backend = 'nix,

    machines
      | { _ : onix.Machine }
      | onix.NameMatchesKey
      =
        (core |> std.record.filter (fun _name m => is_nixos m) |> std.record.map project)
        & {
          aspen2 = {
            # hardware.facterReportPath must sit under onixos/; the report
            # stays in machines/aspen2 and onixos/nix/machines.nix loads it.
            age_public_key = (std.array.first (import "../sops/machines/aspen2/key.json")).publickey,
            # Clan never set a systemd watchdog on aspen2.
            deploy.safety.watchdog.enable = false,
          },
        },

    instances
      | { _ : onix.Instance }
      =
        (import "instances/nix-signing-key.ncl")
        & (import "instances/nix-builder-ssh.ncl")
        & (import "instances/berkeley-mono-font.ncl")
        & (import "instances/nix-gc.ncl")
        & (import "instances/grafana.ncl")
        & (import "instances/homepage-dashboard.ncl")
        & (import "instances/loki.ncl")
        & (import "instances/arxiv-corpus.ncl")
        & (import "instances/laya.ncl")
        & (import "instances/mesh-llm.ncl")
        & (import "instances/sshd.ncl")
        & (import "instances/users.ncl")
        & (import "instances/home-manager-profiles.ncl")
        & (import "instances/niks3.ncl")
        & (import "instances/nix-build-farm.ncl")
        & (import "instances/prometheus.ncl")
        & (import "instances/tailscale.ncl")
        & (import "instances/borgbackup.ncl"),
  }
