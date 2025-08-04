{ lib, ... }:
let
  inherit (lib) mkDefault mkIf;
  inherit (lib.types) attrsOf anything;
in
{
  _class = "clan.service";
  manifest.name = "static-server";

  roles = {
    server = {
      interface = {
        # Freeform module - any attribute becomes a static-server setting
        freeformType = attrsOf anything;
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              cfg = extendSettings {
                # Defaults
                port = mkDefault 8888;
                directory = mkDefault "/var/www/static";
                createTestPage = mkDefault true;
                testPageTitle = mkDefault "Static Server Test";
                testPageContent = mkDefault "";
              };
            in
            {
              systemd.services.static-server = {
                description = "Static file server";
                after = [ "network.target" ];
                wantedBy = [ "multi-user.target" ];

                preStart = mkIf cfg.createTestPage ''
                  mkdir -p ${cfg.directory}
                  cat > ${cfg.directory}/index.html <<EOF
                  <!DOCTYPE html>
                  <html>
                  <head>
                      <title>${cfg.testPageTitle}</title>
                      <style>
                          body { 
                              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
                              padding: 50px; 
                              background: #f5f5f5; 
                              margin: 0;
                          }
                          .container { 
                              max-width: 800px; 
                              margin: 0 auto; 
                              background: white; 
                              padding: 40px; 
                              border-radius: 12px; 
                              box-shadow: 0 2px 20px rgba(0,0,0,0.1); 
                          }
                          h1 { 
                              color: #333; 
                              margin-top: 0;
                          }
                          .info { 
                              background: #f0f8ff; 
                              padding: 20px; 
                              border-radius: 8px; 
                              margin: 20px 0; 
                              border-left: 4px solid #4a90e2;
                          }
                          .info p { 
                              margin: 5px 0; 
                          }
                          .success {
                              color: #27ae60;
                              font-weight: bold;
                          }
                          code {
                              background: #f4f4f4;
                              padding: 2px 6px;
                              border-radius: 3px;
                              font-family: 'Courier New', monospace;
                          }
                      </style>
                  </head>
                  <body>
                      <div class="container">
                          <h1>🚀 ${cfg.testPageTitle}</h1>
                          <p class="success">✓ Static server is running successfully!</p>
                          
                          <div class="info">
                              <p><strong>Server Details:</strong></p>
                              <p>📁 Serving from: <code>${cfg.directory}</code></p>
                              <p>🔌 Port: <code>${toString cfg.port}</code></p>
                              <p>📅 Generated: <script>document.write(new Date().toLocaleString());</script></p>
                              <p>🖥️ Hostname: <code>${config.networking.hostName}</code></p>
                          </div>
                          
                          ${cfg.testPageContent}
                          
                          <p>You can place any static files in <code>${cfg.directory}</code> and they will be served.</p>
                      </div>
                  </body>
                  </html>
                  EOF
                '';

                script = ''
                  cd ${cfg.directory}
                  ${pkgs.python3}/bin/python -m http.server ${toString cfg.port}
                '';

                serviceConfig = {
                  Restart = "always";
                  RestartSec = 3;
                  User = "nobody";
                  Group = "nogroup";

                  # Security hardening
                  PrivateTmp = true;
                  ProtectHome = true;
                  ProtectSystem = "strict";
                  ReadWritePaths = [ cfg.directory ];
                  NoNewPrivileges = true;
                };
              };

              # Ensure the directory exists with correct permissions
              systemd.tmpfiles.rules = [
                "d ${cfg.directory} 0755 nobody nogroup -"
              ];

              # Open firewall port if needed
              networking.firewall.allowedTCPPorts = [ cfg.port ];

              # Add python3 to system packages
              environment.systemPackages = [ pkgs.python3 ];
            };
        };
    };
  };

  # No perMachine configuration needed for static-server
  perMachine = _: {
    nixosModule = _: { };
  };
}
