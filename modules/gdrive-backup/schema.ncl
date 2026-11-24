# gdrive-backup settings schema — single source of truth.
#
# Consumed by:
#   - Nix module (default.nix) via mk-settings.nix for interface and defaults
#   - settings-contracts.ncl for inventory validation
{
  default = {
    remoteName = {
      type = "string",
      default = "google-drive",
      description = "rclone remote section name inside the SOPS-provisioned rclone.conf",
    },
    repoPrefix = {
      type = "string",
      default = "Onix-Restic-Fleet",
      description = "Top-level folder on Google Drive under which per-host Restic repositories live",
    },
    paths = {
      type = "array_string",
      default = [],
      description = "Filesystem paths to back up on this machine (missing paths are skipped cleanly)",
    },
    excludes = {
      type = "array_string",
      default = [
        "**/target",
        "**/.cargo-target*",
        "**/node_modules",
        "**/.direnv",
        "**/.cache",
        "**/__pycache__",
        "**/.venv",
        "*.pyc",
        "*.o",
        "/var/cache",
        "/var/tmp",
        "/tmp",
      ],
      description = "Restic --exclude patterns",
    },
    schedule = {
      type = "string",
      default = "*-*-* 03:30:00",
      description = "systemd OnCalendar schedule for automated backups",
    },
    randomizedDelaySec = {
      type = "string",
      default = "30m",
      description = "systemd timer RandomizedDelaySec jitter",
    },
    keepDaily = {
      type = "number",
      default = 7,
      description = "Number of daily Restic snapshots to retain",
    },
    keepWeekly = {
      type = "number",
      default = 4,
      description = "Number of weekly Restic snapshots to retain",
    },
    keepMonthly = {
      type = "number",
      default = 6,
      description = "Number of monthly Restic snapshots to retain",
    },
    maxTransfer = {
      type = "string",
      default = "650G",
      description = "Per-run rclone upload cap (--max-transfer --cutoff-mode=soft) below Google Drive's 750G/24h quota",
    },
    tpsLimit = {
      type = "number",
      default = 8,
      description = "rclone --tpslimit API request rate cap for Google Drive",
    },
    bandwidthLimit = {
      type = "nullable_string",
      default = null,
      description = "Optional rclone --bwlimit cap (e.g. 25M)",
    },
    enableTimer = {
      type = "bool",
      default = true,
      description = "Enable the scheduled systemd backup timer when paths is non-empty",
    },
    installCli = {
      type = "bool",
      default = true,
      description = "Install rclone-<remoteName> and restic-<instanceName> operator CLI wrappers",
    },
  },

  vault = {
    primaryGenerator = {
      type = "string",
      default = "gdrive-backup-primary",
      description = "Clan vars generator providing the primary Google Drive rclone-conf",
    },
    primaryRemote = {
      type = "string",
      default = "google-drive",
      description = "rclone remote name inside primaryGenerator's rclone-conf",
    },
    personalGenerator = {
      type = "string",
      default = "gdrive-backup-personal",
      description = "Clan vars generator providing the personal Google Drive rclone-conf",
    },
    personalRemote = {
      type = "string",
      default = "google-drive-personal",
      description = "rclone remote name inside personalGenerator's rclone-conf",
    },
    vaultFolder = {
      type = "string",
      default = "Onix-Vault",
      description = "Top-level folder on each Google Drive storing the encrypted union vault",
    },
    mountEnable = {
      type = "bool",
      default = true,
      description = "Mount the unified 60 TiB encrypted vault as a FUSE filesystem",
    },
    mountPoint = {
      type = "string",
      default = "/mnt/gdrive-vault",
      description = "Filesystem mountpoint for the unified encrypted vault",
    },
    mountUser = {
      type = "string",
      default = "brittonr",
      description = "Local user whose uid/gid owns files in the FUSE mount",
    },
    vfsCacheMaxSize = {
      type = "string",
      default = "20G",
      description = "Maximum local VFS cache size for the FUSE mount",
    },
    vfsCacheMaxAge = {
      type = "string",
      default = "24h",
      description = "Maximum age of cached objects in the FUSE VFS cache",
    },
    tpsLimit = {
      type = "number",
      default = 8,
      description = "rclone --tpslimit API rate limit for Google Drive",
    },
    s3Enable = {
      type = "bool",
      default = false,
      description = "Serve the unified encrypted vault over S3 via rclone serve s3",
    },
    s3ListenAddress = {
      type = "string",
      default = "127.0.0.1",
      description = "IP address to bind rclone serve s3 (e.g. Tailscale IP)",
    },
    s3Port = {
      type = "port",
      default = 39100,
      description = "TCP port for rclone serve s3",
    },
    s3AccessKeyId = {
      type = "string",
      default = "onix-gdrive-vault",
      description = "S3 access key ID paired with the Clan SOPS s3-secret-key",
    },
    s3OpenTailscaleFirewall = {
      type = "bool",
      default = true,
      description = "Allow s3Port on tailscale0 when s3Enable is true",
    },
  },
}
