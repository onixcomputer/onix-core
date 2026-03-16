# VM test: harmonia binary cache serves nix store paths over HTTP.
#
# Two-machine test:
#   server: runs harmonia, signs store paths with a generated key
#   client: fetches a store path from the server's cache
{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "harmonia";

  nodes.server =
    { pkgs, ... }:
    {
      virtualisation.graphics = false;

      # Generate a signing key at activation time
      system.activationScripts.harmonia-key = ''
        if [ ! -f /var/lib/harmonia/key ]; then
          mkdir -p /var/lib/harmonia
          ${pkgs.nix}/bin/nix-store --generate-binary-cache-key \
            test-cache /var/lib/harmonia/key /var/lib/harmonia/key.pub
          chown harmonia:harmonia /var/lib/harmonia/key /var/lib/harmonia/key.pub
        fi
      '';

      services.harmonia.cache = {
        enable = true;
        signKeyPaths = [ "/var/lib/harmonia/key" ];
        settings = {
          bind = "[::]:5000";
          workers = 2;
          max_connection_rate = 256;
          priority = 30;
        };
      };

      networking.firewall.allowedTCPPorts = [ 5000 ];
    };

  nodes.client =
    { pkgs, ... }:
    {
      virtualisation.graphics = false;
      environment.systemPackages = [
        pkgs.curl
        pkgs.nix
      ];
    };

  testScript = ''
    start_all()

    server.wait_for_unit("harmonia.service")
    server.wait_for_open_port(5000)

    # Harmonia responds to nix-cache-info
    output = client.succeed("curl -sf http://server:5000/nix-cache-info")
    assert "StoreDir: /nix/store" in output, f"Bad nix-cache-info: {output}"
    assert "Priority: 30" in output, f"Missing priority in cache info: {output}"

    # Build something trivial on the server so the store has a path to serve
    server.succeed("nix-build -E 'derivation { name = \"test-pkg\"; system = builtins.currentSystem; builder = \"/bin/sh\"; args = [\"-c\" \"echo hello > $out\"]; }' --no-out-link")

    # The narinfo endpoint works for that path
    store_path = server.succeed("nix-build -E 'derivation { name = \"test-pkg\"; system = builtins.currentSystem; builder = \"/bin/sh\"; args = [\"-c\" \"echo hello > $out\"]; }' --no-out-link").strip()
    hash_part = store_path.split("/")[-1].split("-")[0]

    narinfo = client.succeed(f"curl -sf http://server:5000/{hash_part}.narinfo")
    assert "StorePath:" in narinfo, f"Bad narinfo response: {narinfo}"
    assert "Sig:" in narinfo, f"Missing signature in narinfo: {narinfo}"
  '';
}
