# Runs the inline `tests` of every service in onixos/services and checks the
# inventory against the OnixOS contract. `onix check` evaluates only module
# interfaces, so these tests run here (flake check `onixos-services`).
fun onix =>
  let service_modules = [
    import "services/arxiv-corpus.ncl",
    import "services/berkeley-mono-font.ncl",
    import "services/borgbackup.ncl",
    import "services/grafana.ncl",
    import "services/home-manager-profiles.ncl",
    import "services/homepage-dashboard.ncl",
    import "services/laya.ncl",
    import "services/loki.ncl",
    import "services/mesh-llm.ncl",
    import "services/niks3.ncl",
    import "services/nix-build-farm.ncl",
    import "services/nix-builder-ssh.ncl",
    import "services/nix-gc.ncl",
    import "services/nix-signing-key.ncl",
    import "services/openssh-keys.ncl",
    import "services/prometheus.ncl",
    import "services/sshd.ncl",
    import "services/tailscale.ncl",
    import "services/users.ncl",
  ]
  in
  let inventory = ((import "inventory.ncl") onix) | onix.Inventory in
  {
    services = service_modules |> std.array.map (fun module => (module onix).tests),
    instances = std.record.fields inventory.instances,
  }
