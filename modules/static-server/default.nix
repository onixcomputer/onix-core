{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  inherit (lib) mkIf;
in
{
  _class = "clan.service";
  manifest = {
    name = "static-server";
    readme = "Static file server for hosting web content and assets";
  };

  roles = {
    server = {
      description = "Static file server that serves web content and assets";
      interface = mkSettings.mkInterface schema.server;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              pkgs,
              lib,
              ...
            }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              cfg = extendSettings (ms.mkDefaults schema.server);
              serviceName =
                if cfg.serviceSuffix != "" then "static-server-${cfg.serviceSuffix}" else "static-server";
            in
            {
              systemd.services.${serviceName} = {
                description = "Static file server${
                  if cfg.serviceSuffix != "" then " (${cfg.serviceSuffix})" else ""
                }";
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
                          .access-public {
                              color: #d73502;
                              font-weight: bold;
                          }
                          .access-private {
                              color: #1971c2;
                              font-weight: bold;
                          }
                      </style>
                  </head>
                  <body>
                      <div class="container">
                          <h1>${cfg.testPageTitle}</h1>
                          <p class="success">Static server is running successfully!</p>
                          
                          <div class="info">
                              <p><strong>Server Details:</strong></p>
                              <p>Serving from: <code>${cfg.directory}</code></p>
                              <p>Port: <code>${toString cfg.port}</code></p>
                              <p>Hostname: <code>${config.networking.hostName}</code></p>
                              <p>Service Name: <code>${serviceName}</code></p>
                              <p>Access Mode: <span class="${
                                if cfg.isPublic then "access-public" else "access-private"
                              }">${if cfg.isPublic then "PUBLIC" else "PRIVATE (Tailscale Only)"}</span></p>
                              ${lib.optionalString (cfg.domain != "" && cfg.subdomain != "") ''
                                <p>URL: <code>https://${cfg.subdomain}.${cfg.domain}</code></p>
                              ''}
                          </div>
                          
                          ${cfg.testPageContent}
                      </div>
                  </body>
                  </html>
                  EOF
                '';

                script = ''
                  ${pkgs.static-web-server}/bin/static-web-server \
                    --host 0.0.0.0 \
                    --port ${toString cfg.port} \
                    --root ${cfg.directory} \
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
                  ReadWritePaths = [ cfg.directory ];
                  NoNewPrivileges = true;
                };
              };

              systemd.tmpfiles.rules = [
                "d ${cfg.directory} 0755 nobody nogroup -"
              ];

              networking.firewall.allowedTCPPorts = [ cfg.port ];
            };
        };
    };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
