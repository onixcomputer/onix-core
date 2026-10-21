# One tailnet identity. Tailscale forwards TLS to a loopback-only proxy.
# Traefik terminates custom-domain TLS and passes MagicDNS TLS back to Serve.
{ lib, pkgs, ... }:
let
  hostname = "britton-desktop.bison-tailor.ts.net";
  loopback = "127.0.0.1";
  trustedProxyRange = "${loopback}/32";
  publicHttpPort = 80;
  publicHttpsPort = 443;
  proxyHttpPort = 18080;
  proxyHttpsPort = 18443;
  serveHttpsPort = 8443;
  bridgePort = 8787;
  proxyProtocolVersion = 2;
  requestTimeoutSeconds = 10;
  retryDelay = "10s";
  startLimitSeconds = 1200;
  startLimitAttempts = 30;
  apiSocket = "/run/tailscale/tailscaled.sock";
  apiUrl = "http://local-tailscaled.sock/localapi/v0/serve-config";
  proxyHttpAddress = "${loopback}:${toString proxyHttpPort}";
  proxyHttpsAddress = "${loopback}:${toString proxyHttpsPort}";
  serveConfig = {
    TCP = {
      ${toString publicHttpPort} = {
        TCPForward = proxyHttpAddress;
        ProxyProtocol = proxyProtocolVersion;
      };
      ${toString publicHttpsPort} = {
        TCPForward = proxyHttpsAddress;
        ProxyProtocol = proxyProtocolVersion;
      };
      ${toString serveHttpsPort}.HTTPS = true;
    };
    Web.${"${hostname}:${toString serveHttpsPort}"}.Handlers = {
      "/".Proxy = "http://${loopback}:${toString bridgePort}";
      "/wiki/".Path = "/home/brittonr/.local/state/onix-wiki/tailscale/public";
    };
  };
  serveConfigFile = (pkgs.formats.json { }).generate "desktop-tailnet-serve.json" serveConfig;
  publish = pkgs.writeShellApplication {
    name = "desktop-tailnet-proxy-publish";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      # This module owns the complete Serve config. Replace it atomically.
      curl --fail --silent --show-error \
        --max-time ${toString requestTimeoutSeconds} \
        --unix-socket ${lib.escapeShellArg apiSocket} \
        --header 'Content-Type: application/json' \
        --data-binary @${serveConfigFile} \
        ${lib.escapeShellArg apiUrl}
    '';
  };
in
{
  system.build.desktopTailnetServeConfig = serveConfigFile;
  system.build.desktopTailnetProxyPublish = publish;

  services.traefik = {
    staticConfigOptions.entryPoints = {
      web = {
        address = lib.mkForce proxyHttpAddress;
        proxyProtocol.trustedIPs = [ trustedProxyRange ];
        http.redirections.entrypoint.to = lib.mkForce ":${toString publicHttpsPort}";
      };
      websecure = {
        address = lib.mkForce proxyHttpsAddress;
        proxyProtocol.trustedIPs = [ trustedProxyRange ];
      };
    };
    # Homepage admits localhost:8082. The router admits only home.onix.computer.
    dynamicConfigOptions.http.services.home.loadBalancer.passHostHeader = false;
    dynamicConfigOptions.tcp = {
      routers.tailnet-ui = {
        entryPoints = [ "websecure" ];
        rule = "HostSNI(`${hostname}`)";
        service = "tailnet-ui";
        tls.passthrough = true;
      };
      services.tailnet-ui.loadBalancer.servers = [
        { address = "${hostname}:${toString serveHttpsPort}"; }
      ];
    };
  };

  systemd.services.collie-serve = {
    description = "Desktop tailnet proxy and wiki front door";
    after = [
      "tailscaled.service"
      "traefik.service"
      "network-online.target"
    ];
    requires = [
      "tailscaled.service"
      "traefik.service"
    ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ serveConfigFile ];
    startLimitIntervalSec = startLimitSeconds;
    startLimitBurst = startLimitAttempts;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe publish;
      Restart = "on-failure";
      RestartSec = retryDelay;
    };
  };
}
