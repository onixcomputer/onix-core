{
  config,
  lib,
  pkgs,
  ...
}:
let
  httpsPort = 443;
  restartDelay = "10s";
  startLimitSeconds = 1200;
  startLimitAttempts = 30;
  loopbackAddress = "127.0.0.1";
  searx = config.services.searx;
in
{
  assertions = [
    {
      assertion = searx.enable && searx.settings.server.bind_address == loopbackAddress;
      message = "The SearXNG Tailscale proxy requires a loopback SearXNG listener.";
    }
    {
      assertion = !searx.openFirewall;
      message = "The SearXNG Tailscale proxy does not require an open backend firewall port.";
    }
  ];

  services.searx.limiterSettings.botdetection.trusted_proxies = [
    "127.0.0.1/32"
    "::1/128"
  ];

  systemd.services.searxng-serve = {
    description = "Private SearXNG Tailscale HTTPS endpoint";
    after = [
      "tailscaled.service"
      "network-online.target"
      "uwsgi.service"
    ];
    wants = [
      "tailscaled.service"
      "network-online.target"
      "uwsgi.service"
    ];
    wantedBy = [ "multi-user.target" ];
    startLimitIntervalSec = startLimitSeconds;
    startLimitBurst = startLimitAttempts;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe pkgs.tailscale} serve --bg --https=${toString httpsPort} --set-path=/ http://${loopbackAddress}:${toString searx.settings.server.port}";
      Restart = "on-failure";
      RestartSec = restartDelay;
    };
  };
}
