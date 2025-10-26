{
  # Database cleanup service for Option 3 reset
  systemd.services.database-nuke = {
    description = "Nuclear database cleanup for fresh Keycloak start";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };

    script = ''
      echo "🚀 Nuclear Database Cleanup"

      # Remove PostgreSQL data
      if [ -d "/var/lib/postgresql" ]; then
        echo "Removing PostgreSQL data..."
        rm -rf /var/lib/postgresql/
        echo "✅ PostgreSQL data removed"
      fi

      # Remove Keycloak data
      if [ -d "/var/lib/keycloak-adeci-terraform" ]; then
        echo "Removing Keycloak terraform data..."
        rm -rf /var/lib/keycloak-adeci-terraform/
        echo "✅ Keycloak terraform data removed"
      fi

      # Remove any other keycloak directories
      find /var/lib -maxdepth 1 -name '*keycloak*' -type d -exec rm -rf {} + 2>/dev/null || true

      # Clean cache and temp
      find /tmp -name '*keycloak*' -exec rm -rf {} + 2>/dev/null || true
      find /var/cache -name '*postgres*' -exec rm -rf {} + 2>/dev/null || true

      echo "🎯 Database completely nuked - ready for fresh start"

      # Disable this service after running once
      systemctl disable database-nuke.service || true
    '';
  };
}
