{
  self,
  pkgs,
  lib,
  ...
}:
let
  config = self.nixosConfigurations.britton-desktop.config;
  traefik = config.services.traefik;
  serve = builtins.fromJSON (builtins.readFile config.system.build.desktopTailnetServeConfig);
  expectedHttpAddress = "127.0.0.1:18080";
  expectedHttpsAddress = "127.0.0.1:18443";
  expectedBackendAddress = "britton-desktop.bison-tailor.ts.net:8443";
  expectedProxySources = [ "127.0.0.1/32" ];
  expectedCiSources = [ "100.64.0.0/10" ];
  publicHttpsPort = "443";
  proxyProtocolVersion = 2;
  actual = {
    httpAddress = traefik.staticConfigOptions.entryPoints.web.address;
    httpsAddress = traefik.staticConfigOptions.entryPoints.websecure.address;
    trustedSources = traefik.staticConfigOptions.entryPoints.websecure.proxyProtocol.trustedIPs;
    redirectPort = traefik.staticConfigOptions.entryPoints.web.http.redirections.entrypoint.to;
    passHostHeader = traefik.dynamicConfigOptions.http.services.home.loadBalancer.passHostHeader;
    passthrough = traefik.dynamicConfigOptions.tcp.routers.tailnet-ui.tls.passthrough;
    backendAddress =
      (builtins.head traefik.dynamicConfigOptions.tcp.services.tailnet-ui.loadBalancer.servers).address;
    ciSources =
      traefik.dynamicConfigOptions.http.middlewares.radicle-ci-reports-tailnet-only.ipAllowList.sourceRange;
    tcpForward = serve.TCP.${publicHttpsPort}.TCPForward;
    proxyProtocol = serve.TCP.${publicHttpsPort}.ProxyProtocol;
  };
  admits =
    candidate:
    candidate.httpAddress == expectedHttpAddress
    && candidate.httpsAddress == expectedHttpsAddress
    && candidate.trustedSources == expectedProxySources
    && candidate.redirectPort == ":${publicHttpsPort}"
    && !candidate.passHostHeader
    && candidate.passthrough
    && candidate.backendAddress == expectedBackendAddress
    && candidate.ciSources == expectedCiSources
    && candidate.tcpForward == expectedHttpsAddress
    && candidate.proxyProtocol == proxyProtocolVersion;
  tests = {
    configuredTransport = admits actual;
    rejectsUnsupportedHomepageHost = !admits (actual // { passHostHeader = true; });
    rejectsWildcardListener = !admits (actual // { httpsAddress = ":18443"; });
    rejectsUntrustedProxySources = !admits (actual // { trustedSources = [ "0.0.0.0/0" ]; });
    rejectsProxyPortRedirect = !admits (actual // { redirectPort = ":18443"; });
    rejectsTlsTerminationForMagicDns = !admits (actual // { passthrough = false; });
    rejectsCiAccessExpansion = !admits (actual // { ciSources = [ "0.0.0.0/0" ]; });
    rejectsMissingClientIdentity = !admits (actual // { proxyProtocol = 0; });
    preservesUiAndWiki =
      serve.Web.${expectedBackendAddress}.Handlers == {
        "/".Proxy = "http://127.0.0.1:8787";
        "/wiki/".Path = "/home/brittonr/.local/state/onix-wiki/tailscale/public";
      };
    retainsOnlyRequiredRoutes =
      builtins.attrNames traefik.dynamicConfigOptions.http.routers == [
        "home"
        "radicle-ci-reports"
        "traefik-dashboard"
      ];
  };
in
{
  checks.desktop-tailnet-proxy =
    assert lib.assertMsg (lib.all (value: value) (
      builtins.attrValues tests
    )) "The desktop tailnet proxy contract failed";
    pkgs.runCommand "desktop-tailnet-proxy-checks"
      {
        results = builtins.toJSON tests;
      }
      ''
        printf '%s\n' "$results" > "$out"
      '';
}
