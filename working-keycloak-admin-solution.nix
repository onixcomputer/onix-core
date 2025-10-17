# Working solution for Keycloak admin user creation
# This configuration combines multiple methods to ensure admin user creation works

{ lib, pkgs, ... }:
let
  # Admin credentials
  adminUsername = "admin";
  adminPassword = "admin-adeci";

  # Database configuration
  dbPasswordFile = "/var/lib/keycloak/db-password";

  # Keycloak settings
  hostname = "auth.robitzs.ch";
  httpPort = 8080;
in
{
  # PostgreSQL database setup
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "keycloak" ];
    ensureUsers = [
      {
        name = "keycloak";
        ensureDBOwnership = true;
      }
    ];
  };

  # Keycloak service with working admin creation
  services.keycloak = {
    enable = true;

    # Method 1: Use initialAdminPassword (this should work in most cases)
    initialAdminPassword = adminPassword;

    # Database configuration
    database = {
      type = "postgresql";
      host = "localhost";
      port = 5432;
      name = "keycloak";
      username = "keycloak";
      passwordFile = dbPasswordFile;
      createLocally = false; # We're creating it manually above
    };

    # Essential settings for proper initialization
    settings = {
      hostname = hostname;
      http-enabled = true;
      http-port = httpPort;
      proxy-headers = "xforwarded";

      # Important: These settings help with initialization
      http-relative-path = "/"; # Don't use /auth for modern Keycloak
      hostname-strict = false; # Allow flexible hostname handling
      hostname-strict-backchannel = false;

      # Database settings
      db = "postgres";
      db-url-host = "localhost";
      db-url-port = "5432";
      db-url-database = "keycloak";
      db-username = "keycloak";
    };
  };

  # Enhanced systemd service configuration
  systemd.services.keycloak = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];

    # Multiple admin creation methods (belt and suspenders approach)
    environment = {
      # Method 2: KC_BOOTSTRAP_* environment variables (modern Keycloak)
      KC_BOOTSTRAP_ADMIN_USERNAME = adminUsername;
      KC_BOOTSTRAP_ADMIN_PASSWORD = adminPassword;

      # Method 3: KEYCLOAK_ADMIN environment variables (legacy fallback)
      KEYCLOAK_ADMIN = adminUsername;
      KEYCLOAK_ADMIN_PASSWORD = adminPassword;

      # Database environment variables
      KC_DB = "postgres";
      KC_DB_URL_HOST = "localhost";
      KC_DB_URL_PORT = "5432";
      KC_DB_URL_DATABASE = "keycloak";
      KC_DB_USERNAME = "keycloak";
    };

    # Enhanced service configuration
    serviceConfig = {
      # Ensure proper user and permissions
      User = "keycloak";
      Group = "keycloak";

      # Method 4: Command line bootstrap parameters
      ExecStart = lib.mkForce [
        "" # Clear existing ExecStart
        "${pkgs.keycloak}/bin/kc.sh start --bootstrap-admin-username=${adminUsername} --bootstrap-admin-password=${adminPassword} --optimized"
      ];

      # Restart policy for reliability
      Restart = "always";
      RestartSec = "30s";

      # Environment file for sensitive data
      EnvironmentFile = "-/var/lib/keycloak/environment";
    };

    # Comprehensive pre-start checks and initialization
    preStart = ''
            echo "=== Keycloak Pre-Start Initialization ==="
            echo "Timestamp: $(date)"
            echo "Hostname: ${hostname}"
            echo "HTTP Port: ${toString httpPort}"
            echo "Admin User: ${adminUsername}"

            # Ensure database is ready
            echo "Waiting for PostgreSQL to be ready..."
            while ! ${pkgs.postgresql}/bin/pg_isready -h localhost -p 5432; do
              echo "PostgreSQL not ready, waiting..."
              sleep 2
            done
            echo "✓ PostgreSQL is ready"

            # Create database password file if it doesn't exist
            if [ ! -f "${dbPasswordFile}" ]; then
              echo "Creating database password file..."
              mkdir -p "$(dirname "${dbPasswordFile}")"
              echo "keycloak-db-password-$(date +%s)" > "${dbPasswordFile}"
              chown keycloak:keycloak "${dbPasswordFile}"
              chmod 600 "${dbPasswordFile}"
              echo "✓ Database password file created"
            fi

            # Create environment file with all needed variables
            echo "Creating environment file..."
            cat > /var/lib/keycloak/environment <<EOF
      KC_DB_PASSWORD=$(cat ${dbPasswordFile})
      KC_HOSTNAME=${hostname}
      KC_HTTP_ENABLED=true
      KC_HTTP_PORT=${toString httpPort}
      KC_PROXY_HEADERS=xforwarded
      EOF
            chown keycloak:keycloak /var/lib/keycloak/environment
            chmod 600 /var/lib/keycloak/environment
            echo "✓ Environment file created"

            # Test database connectivity
            echo "Testing database connectivity..."
            if ${pkgs.postgresql}/bin/psql -h localhost -U keycloak -d keycloak -c "SELECT 1;" > /dev/null 2>&1; then
              echo "✓ Database connection successful"
            else
              echo "⚠ Database connection test failed, but continuing..."
            fi

            echo "=== Pre-Start Complete ==="
    '';

    # Post-start verification
    postStart = ''
      echo "=== Keycloak Post-Start Verification ==="

      # Wait for Keycloak to be ready
      echo "Waiting for Keycloak to start..."
      for i in {1..30}; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:${toString httpPort}/ | grep -q "200"; then
          echo "✓ Keycloak is responding on port ${toString httpPort}"
          break
        fi
        echo "Attempt $i/30: Keycloak not ready yet..."
        sleep 10
      done

      # Test admin console
      if curl -s http://localhost:${toString httpPort}/admin/ | grep -q "Keycloak\|admin"; then
        echo "✓ Admin console is accessible"
      else
        echo "⚠ Admin console may not be ready yet"
      fi

      # Test master realm
      if curl -s http://localhost:${toString httpPort}/realms/master/.well-known/openid_connect_configuration | grep -q "token_endpoint"; then
        echo "✓ Master realm is configured"
      else
        echo "⚠ Master realm configuration not found"
      fi

      echo "=== Post-Start Complete ==="
      echo "Admin Console: https://${hostname}/admin/"
      echo "Admin User: ${adminUsername}"
      echo "Admin Password: ${adminPassword}"
    '';
  };

  # Method 5: Separate bootstrap service as fallback
  systemd.services.keycloak-admin-bootstrap = {
    description = "Keycloak Admin Bootstrap (fallback)";
    after = [ "keycloak.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "keycloak";
      Group = "keycloak";
    };

    script = ''
      echo "Running admin bootstrap fallback..."

      # Wait for Keycloak to be fully started
      sleep 30

      # Try the bootstrap-admin command as fallback
      if ! curl -s http://localhost:${toString httpPort}/realms/master/protocol/openid_connect/token \
          -d "username=${adminUsername}&password=${adminPassword}&grant_type=password&client_id=admin-cli" \
          | grep -q "access_token"; then

        echo "Admin user not found, attempting bootstrap creation..."

        # Stop Keycloak temporarily
        systemctl stop keycloak || true
        sleep 5

        # Run bootstrap command
        cd /var/lib/keycloak
        export KC_DB_PASSWORD=$(cat ${dbPasswordFile})
        ${pkgs.keycloak}/bin/kc.sh bootstrap-admin user \
          --username ${adminUsername} \
          --password:env ADMIN_PASS \
          --no-prompt || echo "Bootstrap command failed"

        # Restart Keycloak
        systemctl start keycloak

        echo "Bootstrap attempt completed"
      else
        echo "Admin user already exists, skipping bootstrap"
      fi
    '';

    environment = {
      ADMIN_PASS = adminPassword;
    };
  };

  # Nginx proxy configuration
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    virtualHosts."${hostname}" = {
      locations."/" = {
        proxyPass = "http://localhost:${toString httpPort}";
        proxyWebsockets = true;
        extraConfig = ''
          # Essential headers for Keycloak
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Port $server_port;

          # Timeouts for admin operations
          proxy_connect_timeout 60s;
          proxy_send_timeout 60s;
          proxy_read_timeout 60s;
        '';
      };
    };
  };

  # Ensure proper file permissions and directories
  systemd.tmpfiles.rules = [
    "d /var/lib/keycloak 0755 keycloak keycloak -"
    "f /var/lib/keycloak/db-password 0600 keycloak keycloak -"
    "f /var/lib/keycloak/environment 0600 keycloak keycloak -"
  ];

  # Create keycloak user if it doesn't exist
  users.users.keycloak = {
    isSystemUser = true;
    group = "keycloak";
    home = "/var/lib/keycloak";
  };

  users.groups.keycloak = { };
}
