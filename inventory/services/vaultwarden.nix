_: {
  instances = {
    "vaultwarden" = {
      module.name = "vaultwarden";
      module.input = "self";
      roles.server = {
        tags."vaultwarden-server" = { };
        settings = {
          # Core Vaultwarden settings
          DOMAIN = "https://vault.bison-tailor.ts.net"; # Tailscale domain
          SIGNUPS_ALLOWED = false; # Set to true to allow new user registrations
          INVITATIONS_ALLOWED = true;
          SHOW_PASSWORD_HINT = false;

          # Traefik integration - will auto-configure if Traefik is available
          traefik = {
            enable = true;
            host = "vault.bison-tailor.ts.net"; # Tailscale domain
            enableAuth = true; # Add Tailscale auth on top of Vaultwarden's auth
            authType = "tailscale"; # Use Tailscale auth
            tailscaleDomain = "bison-tailor.ts.net"; # Your tailnet domain
            middlewares = [ ]; # Additional middlewares beyond defaults
          };

          # Optional: Configure database (defaults to SQLite)
          # DATABASE_URL = "postgresql://user:password@localhost/vaultwarden";

          # Optional: SMTP settings for email
          # SMTP_HOST = "smtp.example.com";
          # SMTP_PORT = 587;
          # SMTP_SECURITY = "starttls";
          # SMTP_FROM = "vaultwarden@example.com";
          # SMTP_USERNAME = "username";
          # SMTP_PASSWORD = "password";
        };
      };
    };
  };
}
