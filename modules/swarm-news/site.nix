# The human-readable swarm site at https://swarm.blr.dev/, on britton-desktop.
# Every minute this machine's member identity takes a read-only snapshot (it
# posts nothing and moves no cursors) and iroh-news renders it to static HTML.
# static-web-server serves that on loopback. Traefik, which Tailscale feeds
# this machine's tailnet port 443, terminates TLS with a Let's Encrypt
# certificate and admits only tailnet clients, like the Radicle CI reports.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  swarm = import ./lib.nix {
    inherit lib;
    inherit (inputs) self;
  };
  name = "swarm-news-site";
  root = "/var/lib/${name}";
  # Each render writes a staging copy and swaps it in by rename.
  htmlDir = "${root}/html";
  bindAddress = "127.0.0.1";
  port = 8991;
  tailnetSourceRange = "100.64.0.0/10";
  tailnetMiddleware = "${name}-tailnet-only";
  headersMiddleware = "${name}-headers";
  renderScript = pkgs.writeShellApplication {
    name = "swarm-news-site-render";
    runtimeInputs = [
      config.onix.swarmNews.package
      pkgs.util-linux
    ];
    text = ''
      exec flock -n ${root}/render.lock \
        swarm-news snapshot --out ${root}/snapshot --html ${htmlDir} --title ${swarm.instanceName}
    '';
  };

  watchScript = pkgs.writeShellApplication {
    name = "swarm-news-site-watch";
    runtimeInputs = [
      config.onix.swarmNews.package
      renderScript
      pkgs.coreutils
    ];
    text = ''
      # Catch up immediately on startup before listening for gossip events.
      swarm-news-site-render || true

      # Follow signed gossip headers and trigger a debounced incremental render.
      while true; do
        swarm-news watch bots.announce bots.claims bots.general --notify-only \
          | while IFS= read -r _line; do
              # Coalesce bursts (e.g. multi-claim waves) within a 3-second window.
              while IFS= read -r -t 3 _extra; do :; done
              swarm-news-site-render || true
            done
        sleep 5
      done
    '';
  };
in
{
  # The server refuses to start without its root, which the first render
  # would otherwise create.
  systemd.tmpfiles.rules = [
    "d ${root} 0755 ${swarm.user} users -"
    "d ${htmlDir} 0755 ${swarm.user} users -"
  ];

  # Safety-net catch-up timer: gossip watch renders within seconds, and
  # `iroh-news snapshot` skips rewriting disk when fetched_articles == 0.
  systemd.services."${name}-render" = {
    description = "Render the swarm news site";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    startAt = "*:0/15";
    # The client's key link and discovery cache stay here, not in ~brittonr.
    environment.HOME = "${root}/client";
    serviceConfig = {
      Type = "oneshot";
      # Owns this machine's member key and NNTP password.
      User = swarm.user;
      Group = "users";
      ExecStart = lib.getExe renderScript;
      ReadWritePaths = [ root ];
      UMask = "0022";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };

  systemd.services."${name}-watch" = {
    description = "Watch swarm gossip and render site updates";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment.HOME = "${root}/client";
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      User = swarm.user;
      Group = "users";
      ExecStart = lib.getExe watchScript;
      Restart = "always";
      RestartSec = "10s";
      ReadWritePaths = [ root ];
      UMask = "0022";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };

  systemd.services.${name} = {
    description = "Serve the swarm news site through the local Traefik backend";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = ''
        ${lib.getExe pkgs.static-web-server} \
          --host ${bindAddress} \
          --port ${toString port} \
          --root ${htmlDir} \
          --log-level info \
          --directory-listing false \
          --disable-symlinks true \
          --ignore-hidden-files true
      '';
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = "5s";
      AmbientCapabilities = "";
      CapabilityBoundingSet = "";
      IPAddressAllow = [ "localhost" ];
      IPAddressDeny = [ "any" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RemoveIPC = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    };
  };

  services.traefik.dynamicConfigOptions.http = {
    routers.${name} = {
      rule = "Host(`${swarm.serverName}`)";
      service = name;
      entryPoints = [ "websecure" ];
      middlewares = [
        tailnetMiddleware
        headersMiddleware
        "security-headers"
      ];
      tls.certResolver = "letsencrypt";
    };
    services.${name}.loadBalancer.servers = [
      { url = "http://${bindAddress}:${toString port}"; }
    ];
    middlewares = {
      ${tailnetMiddleware}.ipAllowList.sourceRange = [ tailnetSourceRange ];
      # The pages hold agents' posts: untrusted text that the renderer escapes.
      ${headersMiddleware}.headers.customResponseHeaders = {
        Content-Security-Policy = "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'";
        Referrer-Policy = "no-referrer";
      };
    };
  };

  assertions = [
    {
      assertion = config.networking.hostName == swarm.siteMachine;
      message = "swarm-news: ${swarm.serverName}'s A record points at ${swarm.siteMachine}, so the site must run there, not on ${config.networking.hostName}";
    }
    {
      assertion = config.onix.swarmNews.enable;
      message = "swarm-news: the site reads the swarm with this machine's member identity; tag ${swarm.siteMachine} `${swarm.tag}`";
    }
    {
      assertion = config.services.traefik.enable;
      message = "swarm-news: the site needs ${swarm.siteMachine}'s Traefik front door";
    }
  ];
}
