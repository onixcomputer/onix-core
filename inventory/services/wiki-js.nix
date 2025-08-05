_: {
  instances = {
    # Wiki.js documentation platform
    "wiki-js" = {
      module.name = "wiki-js";
      module.input = "self";
      roles.server = {
        tags."wiki-js" = { };
        settings = {
          # Clan-specific settings
          domain = null; # Using Traefik for reverse proxy
          enableSSL = false;

          database = {
            type = "postgres";
            autoSetup = true;
            name = "wikijs";
            user = "wikijs";
          };

          # Git synchronization (optional)
          gitSync = {
            enable = false; # Set to true to enable git sync
            repository = null; # e.g., "git@github.com:myorg/wiki-content.git"
            branch = "main";
            # sshKeyFile = null; # Auto-generated if not specified
            authorName = "Wiki.js";
            authorEmail = "wiki-js@example.com";
          };

          # Wiki.js specific settings (freeform)
          port = 3000;

          # Logging configuration
          logLevel = "info";

          # Wiki.js configuration
          telemetry = {
            clientId = "";
            isEnabled = false;
          };

          # Performance tuning
          pool = {
            min = 2;
            max = 10;
          };

          # File uploads
          uploads = {
            maxFileSize = 104857600; # 100MB
            maxFiles = 10;
          };

          # Security settings
          sessionSecret = null; # Will be auto-generated

          # Search configuration
          search = {
            type = "postgres";
            config = { };
          };

          # Authentication - local by default
          auth = {
            defaultStrategy = "local";
            local = {
              enabled = true;
              selfRegistration = false;
            };
          };

          # Mail configuration (optional)
          mail = {
            enabled = false;
            host = "";
            port = 587;
            secure = true;
            user = "";
            pass = "";
            useDKIM = false;
            dkimDomainName = "";
            dkimKeySelector = "";
            dkimPrivateKey = "";
            from = "wiki@example.com";
            name = "Wiki.js";
          };

          # Editor configuration
          editor = {
            uploadMaxFileSize = 52428800; # 50MB
            uploadMaxFiles = 10;
          };
        };
      };
    };
  };
}
