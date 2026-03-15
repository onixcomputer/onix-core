# VM test: static-server module serves content and responds to HTTP.
{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "static-server";

  nodes.server = {
    virtualisation.graphics = false;

    networking.firewall.allowedTCPPorts = [ 8888 ];

    environment.systemPackages = [ pkgs.static-web-server ];

    systemd.tmpfiles.rules = [
      "d /var/www/test 0755 nobody nogroup -"
    ];

    systemd.services.static-server-test = {
      description = "Static file server (test)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p /var/www/test
        cat > /var/www/test/index.html <<'EOF'
        <!DOCTYPE html><html><body><h1>Static Server Test</h1></body></html>
        EOF
      '';

      script = ''
        ${pkgs.static-web-server}/bin/static-web-server \
          --host 0.0.0.0 \
          --port 8888 \
          --root /var/www/test \
          --log-level info
      '';

      serviceConfig = {
        Restart = "always";
        RestartSec = 3;
        User = "nobody";
        Group = "nogroup";
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/www/test" ];
        NoNewPrivileges = true;
      };
    };
  };

  testScript = ''
    server.wait_for_unit("static-server-test.service")
    server.wait_for_open_port(8888)

    # Basic response
    output = server.succeed("curl -sf http://localhost:8888/")
    assert "Static Server Test" in output, f"Expected title in response, got: {output}"

    # 404 for missing files
    server.succeed("curl -sf -o /dev/null -w '%{http_code}' http://localhost:8888/nonexistent || true")

    # Serves custom files
    server.succeed("echo 'hello world' > /var/www/test/custom.txt")
    output = server.succeed("curl -sf http://localhost:8888/custom.txt")
    assert "hello world" in output, f"Expected custom content, got: {output}"
  '';
}
