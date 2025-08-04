_: {
  instances = {
    # Forgejo Git forge and repository hosting
    "forgejo" = {
      module.name = "forgejo";
      module.input = "self";
      roles.server = {
        tags."git" = { };
        tags."web" = { };
        settings = {
          # Clan convenience options
          domain = "git.example.com";
          enableNginx = true;
          enableDatabase = true;
          databaseType = "postgres";
          enableLFS = true;
          sshPort = 2222; # Use non-standard SSH port to avoid conflicts

          # Email configuration (optional)
          enableMailer = false;
          # smtpHost = "smtp.example.com";
          # smtpPort = 587;
          # smtpFrom = "noreply@example.com";

          # Forgejo-specific settings (freeform)
          settings = {
            # Server configuration
            server = {
              PROTOCOL = "http"; # Nginx handles HTTPS
              HTTP_ADDR = "127.0.0.1"; # Only listen locally for Nginx
              DISABLE_SSH = false;
              START_SSH_SERVER = true; # Built-in SSH server
              BUILTIN_SSH_SERVER_USER = "git";
              SSH_LISTEN_HOST = "0.0.0.0";
              SSH_LISTEN_PORT = 2222;
              OFFLINE_MODE = false;
              APP_DATA_PATH = "/var/lib/forgejo/data";
            };

            # Repository settings
            repository = {
              DEFAULT_BRANCH = "main";
              DEFAULT_PRIVATE = "last"; # Use last setting for new repos
              ENABLE_PUSH_CREATE_USER = true;
              ENABLE_PUSH_CREATE_ORG = true;
              DEFAULT_REPO_UNITS = "repo.code,repo.releases,repo.issues,repo.pulls,repo.wiki,repo.projects,repo.packages,repo.actions";
              PREFIX_ARCHIVE_FILES = true;
              DISABLE_MIGRATIONS = false;
              DISABLE_STARS = false;
            };

            # UI customization
            ui = {
              DEFAULT_THEME = "forgejo-auto"; # Auto dark/light mode
              THEMES = "forgejo-auto,forgejo-light,forgejo-dark,auto,gitea,arc-green";
              REACTIONS = "👍,👎,😄,🎉,😕,❤️,🚀,👀";
              CUSTOM_EMOJIS = "git,forgejo,godot,gitea,codeberg,gitlab,github,gogs";
              DEFAULT_SHOW_FULL_NAME = false;
              SEARCH_REPO_DESCRIPTION = true;
              USE_SERVICE_WORKER = false;
            };

            # Service settings
            service = {
              DISABLE_REGISTRATION = true; # Admin creates users
              REQUIRE_SIGNIN_VIEW = false; # Allow public repos
              REGISTER_EMAIL_CONFIRM = false;
              ENABLE_NOTIFY_MAIL = false; # Disabled unless mailer configured
              ALLOW_ONLY_EXTERNAL_REGISTRATION = false;
              ENABLE_CAPTCHA = false;
              DEFAULT_KEEP_EMAIL_PRIVATE = true;
              DEFAULT_ALLOW_CREATE_ORGANIZATION = true;
              DEFAULT_ENABLE_TIMETRACKING = true;
              NO_REPLY_ADDRESS = "noreply.localhost";
              SHOW_REGISTRATION_BUTTON = false;
              AUTO_WATCH_NEW_REPOS = true;
            };

            # Security settings (secrets handled by clan module)
            security = {
              INSTALL_LOCK = true; # Disable install page
              PASSWORD_HASH_ALGO = "pbkdf2";
              CSRF_COOKIE_HTTP_ONLY = true;
              MIN_PASSWORD_LENGTH = 8;
              PASSWORD_COMPLEXITY = "lower,upper,digit";
            };

            # Database is configured via clan options

            # Session configuration
            session = {
              PROVIDER = "file";
              COOKIE_NAME = "i_like_forgejo";
              COOKIE_SECURE = true; # HTTPS via Nginx
              SAME_SITE = "lax";
              SESSION_LIFE_TIME = 86400; # 24 hours
            };

            # Picture/Avatar settings
            picture = {
              DISABLE_GRAVATAR = false;
              ENABLE_FEDERATED_AVATAR = true;
              AVATAR_UPLOAD_PATH = "/var/lib/forgejo/data/avatars";
              REPOSITORY_AVATAR_UPLOAD_PATH = "/var/lib/forgejo/data/repo-avatars";
              AVATAR_MAX_WIDTH = 4096;
              AVATAR_MAX_HEIGHT = 4096;
              AVATAR_MAX_FILE_SIZE = 1048576; # 1MB
            };

            # Attachment settings
            attachment = {
              ENABLED = true;
              ALLOWED_TYPES = ".csv,.docx,.fodg,.fodp,.fods,.fodt,.gif,.gz,.jpeg,.jpg,.log,.md,.mov,.mp4,.odf,.odg,.odp,.ods,.odt,.patch,.pdf,.png,.pptx,.svg,.tgz,.txt,.webm,.xls,.xlsx,.zip";
              MAX_SIZE = 4; # 4MB
              MAX_FILES = 5;
              STORAGE_TYPE = "local";
              PATH = "/var/lib/forgejo/data/attachments";
            };

            # Log configuration
            log = {
              ROOT_PATH = "/var/lib/forgejo/log";
              MODE = "console";
              LEVEL = "Info";
              STACK_TRACE_LEVEL = "None";
              ENABLE_ACCESS_LOG = false;
              ACCESS_LOG_TEMPLATE = "";
            };

            # Cron tasks
            cron = {
              ENABLED = true;
              RUN_AT_START = true;
            };

            # Git settings
            git = {
              DEFAULT_BRANCH = "main";
              DISABLE_DIFF_HIGHLIGHT = false;
              MAX_GIT_DIFF_LINES = 1000;
              MAX_GIT_DIFF_LINE_CHARACTERS = 5000;
              MAX_GIT_DIFF_FILES = 100;
              ENABLE_AUTO_GIT_WIRE_PROTOCOL = true;
              PULL_REQUEST_PUSH_MESSAGE = true;
              VERBOSE_PUSH = true;
              VERBOSE_PUSH_DELAY = "5s";
            };

            # Mirror settings
            mirror = {
              ENABLED = true;
              DISABLE_NEW_PULL = false;
              DISABLE_NEW_PUSH = false;
              DEFAULT_INTERVAL = "8h";
              MIN_INTERVAL = "10m";
            };

            # API settings
            api = {
              ENABLE_SWAGGER = true;
              MAX_RESPONSE_ITEMS = 50;
              DEFAULT_PAGING_NUM = 30;
              DEFAULT_GIT_TREES_PER_PAGE = 1000;
              DEFAULT_MAX_BLOB_SIZE = 10485760; # 10MB
            };

            # OAuth2 settings - disabled due to nixpkgs bug with JWT secret generation
            oauth2 = {
              ENABLED = false;
              # ACCESS_TOKEN_EXPIRATION_TIME = 3600;
              # REFRESH_TOKEN_EXPIRATION_TIME = 730;
              # INVALIDATE_REFRESH_TOKENS = false;
              # JWT_SIGNING_ALGORITHM = "RS256";
            };

            # LFS configuration (JWT secret handled by clan module)
            lfs = {
              STORAGE_TYPE = "local";
              PATH = "/var/lib/forgejo/data/lfs";
            };

            # Actions (CI/CD) - disabled by default
            actions = {
              ENABLED = false;
              DEFAULT_ACTIONS_URL = "https://code.forgejo.org";
            };

            # Packages registry - disabled by default
            packages = {
              ENABLED = false;
            };

            # Webhook settings
            webhook = {
              ALLOWED_HOST_LIST = "external";
              DELIVER_TIMEOUT = 5;
              SKIP_TLS_VERIFY = false;
              PAGING_NUM = 10;
              PROXY_USE_PROXY = false;
            };

            # Indexer settings
            indexer = {
              ISSUE_INDEXER_TYPE = "bleve";
              ISSUE_INDEXER_PATH = "/var/lib/forgejo/indexers/issues.bleve";
              REPO_INDEXER_ENABLED = true;
              REPO_INDEXER_TYPE = "bleve";
              REPO_INDEXER_PATH = "/var/lib/forgejo/indexers/repos.bleve";
              MAX_FILE_SIZE = 1048576; # 1MB
            };

            # Cache settings
            cache = {
              ADAPTER = "memory";
              INTERVAL = 60;
            };

            # Markup settings
            "markup.markdown" = {
              ENABLED = true;
              FILE_EXTENSIONS = ".md,.markdown";
              ENABLE_MATH = true;
            };

            # Admin settings
            admin = {
              DISABLE_REGULAR_ORG_CREATION = false;
              DEFAULT_EMAIL_NOTIFICATIONS = "enabled";
            };

            # Metrics (Prometheus)
            metrics = {
              ENABLED = false; # Enable if you want Prometheus metrics
              ENABLED_ISSUE_BY_LABEL = false;
              ENABLED_ISSUE_BY_REPOSITORY = false;
              TOKEN = ""; # Set a token if you enable metrics
            };

            # Federation
            federation = {
              ENABLED = false; # Experimental ActivityPub support
            };

            # Other settings
            other = {
              SHOW_FOOTER_VERSION = true;
              SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
              ENABLE_SITEMAP = true;
              ENABLE_FEED = true;
            };
          };

          # Backup configuration (would need to be implemented separately)
          # dump = {
          #   enabled = true;
          #   interval = "daily";
          #   backupAll = true;
          #   type = "tar.gz";
          # };
        };
      };
    };
  };
}
