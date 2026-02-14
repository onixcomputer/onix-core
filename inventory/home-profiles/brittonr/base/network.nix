{ lib, ... }:
{
  options.network = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      tailscale = {
        acceptRoutes = true;
      };
      wifi.rescanDelay = 2;
    };
    description = "Network connectivity settings";
  };
}
