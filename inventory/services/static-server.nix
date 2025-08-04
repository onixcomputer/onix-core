_: {
  instances = {
    # Test instance for britton-fw
    "static-server-test" = {
      module.name = "static-server";
      module.input = "self";
      roles.server = {
        tags."static-test" = { };
        settings = {
          port = 8888;
          directory = "/var/www/test";
          createTestPage = true;
          testPageTitle = "Tailscale-Traefik Public Mode Test";
          testPageContent = ''
            <h2>🔒 Testing Public vs Private Access</h2>
            <p>This page is served by the static-server clan service to test Tailscale-Traefik.</p>

            <div class="info">
              <p><strong>Test Instructions:</strong></p>
              <ol>
                <li>Configure tailscale-traefik with <code>publicMode = true</code></li>
                <li>Set up port forwarding on your router (80 → machine:80, 443 → machine:443)</li>
                <li>Access this page via your domain (e.g., test.blr.dev)</li>
              </ol>
            </div>
          '';
        };
      };
    };
  };
}
