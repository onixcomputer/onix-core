{ lib, ... }:
{
  options.serviceTiming = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      restartSec = {
        fast = "5s";
        normal = "10s";
      };
      timeoutStopSec = "2s";
    };
    description = "Shared systemd service timing values";
  };
}
