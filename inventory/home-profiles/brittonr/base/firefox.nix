{ lib, ... }:
{
  options.firefox = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      ui.density = 1;

      cache = {
        canvasItems = 8192;
        canvasSize = 1024;
      };

      dns = {
        cacheEntries = 10000;
        cacheExpiration = 86400;
      };

      network = {
        maxConnections = 1800;
        maxPersistentPerServer = 10;
        maxUrgentStartExcessivePerHost = 5;
        speculativeParallelLimit = 20;
      };

      privacy.cookieBannerMode = 2;
    };
    description = "Firefox performance and tuning settings";
  };
}
