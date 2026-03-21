{ lib, ... }:
{
  options.timeouts = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      dim = 600; # 10 min - dim/turn off screen
      lock = 1800; # 30 min - lock screen or suspend
      suspend = 3600; # 1 hour - suspend system
      passwordCache = 3600; # 1 hour - bitwarden/rbw lock timeout
    };
    description = "Power management and idle timeout settings (in seconds)";
  };
}
