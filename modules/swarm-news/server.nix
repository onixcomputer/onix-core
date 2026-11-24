# The private swarm news server: a second renews-over-iroh instance beside
# slime. Only machines tagged `swarm-news` are allowlisted and have accounts.
# britton-desktop's member identity is the admin peer that approves machines
# without clan vars. Join requests stay off. The iroh endpoint binds only the
# tailnet address with the n0 relays off, so nothing off the tailnet reaches it.
# `swarm-news-dns` keeps the `_iroh-news.swarm.blr.dev` TXT record on it, and
# points swarm.blr.dev's A record at britton-desktop, which serves the site.
{
  config,
  inputs,
  lib,
  pkgs,
  nclMachines,
  ...
}:
let
  swarm = import ./lib.nix {
    inherit lib;
    inherit (inputs) self;
  };
  irohNews = inputs.renews.packages.${pkgs.stdenv.hostPlatform.system}.iroh-news;
  generators = config.clan.core.vars.generators;
  host = config.networking.hostName;
  members = swarm.members nclMachines;
  endpointIds = lib.genAttrs members swarm.endpointIdOf;
  services = lib.attrNames swarm.serviceAccounts;
  serviceEndpointIds = lib.genAttrs services swarm.serviceEndpointIdOf;
  adminEndpointId = swarm.endpointIdOf swarm.adminMachine;
  instance = config.services.renews-iroh.instances.${swarm.instanceName};
  # The running server writes its ticket here on every start.
  ticketFile = "/var/lib/${instance.stateDirectory}/iroh.ticket";
  dnsTokenFile = swarm.dnsTokenFile generators;
  managedComment = "Managed by swarm-news-dns on ${swarm.serverMachine} (onix-core modules/swarm-news)";

  # Keeps one A record for the site host's tailnet address and one TXT record
  # holding the running server's ticket. Members pin the server id, so a TXT
  # record for another key would only lock them out; never publish one.
  publishDns = pkgs.writeShellApplication {
    name = "swarm-news-dns";
    runtimeInputs = [
      irohNews
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      ticket_file=${lib.escapeShellArg ticketFile}
      # The server writes its ticket a moment after it binds.
      for _ in $(seq 1 30); do
        [ -s "$ticket_file" ] && break
        sleep 2
      done
      if [ ! -s "$ticket_file" ]; then
        echo "swarm-news-dns: no ticket at $ticket_file; is renews-iroh-${swarm.instanceName} running?" >&2
        exit 1
      fi
      ticket=$(tr -d '[:space:]' < "$ticket_file")

      state=$(mktemp -d)
      trap 'rm -rf "$state"' EXIT
      id=$(HOME="$state" iroh-news --state-dir "$state" --server "$ticket" resolve | jq -r .endpoint_id)
      if [ "$id" != ${lib.escapeShellArg (toString swarm.serverEndpointId)} ]; then
        echo "swarm-news-dns: the ticket names endpoint $id, not the server key in vars" >&2
        exit 1
      fi

      token=$(cat "$CREDENTIALS_DIRECTORY/api_token")
      cf() {
        local method=$1 path=$2 body=''${3:-}
        local args=(--silent --show-error --request "$method"
          --header "Authorization: Bearer $token"
          --header "Content-Type: application/json")
        if [ -n "$body" ]; then
          args+=(--data "$body")
        fi
        local response
        if ! response=$(curl "''${args[@]}" "https://api.cloudflare.com/client/v4/$path"); then
          echo "swarm-news-dns: $method $path failed" >&2
          return 1
        fi
        if [ "$(jq -r .success <<< "$response")" != true ]; then
          echo "swarm-news-dns: $method $path: $(jq -c .errors <<< "$response")" >&2
          return 1
        fi
        printf '%s' "$response"
      }

      zone=$(cf GET "zones?name=${swarm.dnsZone}" | jq -r '.result[0].id // empty')
      if [ -z "$zone" ]; then
        echo "swarm-news-dns: Cloudflare has no zone ${swarm.dnsZone}" >&2
        exit 1
      fi

      # Keep exactly one record of this type and name, with this content.
      upsert() {
        local type=$1 name=$2 content=$3
        local want records first extra
        want=$(jq -cn --arg type "$type" --arg name "$name" --arg content "$content" \
          --arg comment ${lib.escapeShellArg managedComment} \
          '{type: $type, name: $name, content: $content, ttl: 300, comment: $comment}
            + (if $type == "A" then {proxied: false} else {} end)')
        records=$(cf GET "zones/$zone/dns_records?type=$type&name=$name")
        first=$(jq -r '.result[0].id // empty' <<< "$records")
        if [ -z "$first" ]; then
          cf POST "zones/$zone/dns_records" "$want" > /dev/null
          echo "created $type $name"
        elif jq -e --argjson want "$want" \
          '.result[0] | .content == $want.content and .ttl == $want.ttl and .comment == $want.comment' \
          <<< "$records" > /dev/null; then
          echo "$type $name is current"
        else
          cf PUT "zones/$zone/dns_records/$first" "$want" > /dev/null
          echo "updated $type $name"
        fi
        # With a second record, members would get either answer.
        while read -r extra; do
          cf DELETE "zones/$zone/dns_records/$extra" > /dev/null
          echo "deleted a second $type $name"
        done < <(jq -r '.result[1:][].id' <<< "$records")
      }

      upsert A ${swarm.serverName} ${swarm.siteTailnetAddress}
      # Quoted, like slime's record in onix.computer.
      upsert TXT ${swarm.discoveryName} "\"ticket=$ticket\""
    '';
  };
in
{
  # A member server declares its own password generator through member.nix.
  clan.core.vars.generators = {
    ${swarm.serverGenerator} = swarm.mkKeyGenerator {
      inherit pkgs irohNews;
      owner = "root";
    };
  }
  // lib.listToAttrs (
    map (
      account: lib.nameValuePair (swarm.passwordGenerator account) (swarm.mkPasswordGenerator pkgs)
    ) (lib.remove host members ++ services)
  );

  services.renews-iroh.instances.${swarm.instanceName} = {
    siteName = "${host}.swarm.local";
    listenAddress = "127.0.0.1:1119";
    irohBindAddress = "${swarm.serverTailnetAddress}:${toString swarm.serverPort}";
    relays = false;
    secretKeyFile = generators.${swarm.serverGenerator}.files.secret-key.path;
    groups = [
      "bots.announce"
      "bots.claims"
      "bots.general"
    ];
    groupDescriptions = {
      "bots.announce" = "Short start/finish announcements for substantial work";
      "bots.claims" = "Active scope claims and releases (mirrored by Kiln)";
      "bots.general" = "Agent questions, handoffs, carve-outs, and coordination";
    };
    retentionDays = 30;
    allowedPeers = lib.filterAttrs (_: id: id != null) (endpointIds // serviceEndpointIds);
    adminPeers = lib.optionalAttrs (adminEndpointId != null) {
      ${swarm.adminMachine} = adminEndpointId;
    };
    bots = lib.genAttrs (members ++ services) (account: {
      passwordFile = generators.${swarm.passwordGenerator account}.files.password.path;
    });
    # 0 disables each cap, as on slime.
    groupCreatesPerDay = 0;
    maxGroups = 0;
    postRatePerMinute = 0;
  };

  # The bind address exists once tailscaled has brought up tailscale0. Until
  # then the unit fails and the module's Restart= retries it.
  systemd.services."renews-iroh-${swarm.instanceName}" = {
    wants = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
  };

  systemd.services.swarm-news-dns = {
    description = "Publish ${swarm.serverName} for the swarm news server";
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "renews-iroh-${swarm.instanceName}.service"
    ];
    # Hourly as well, so a record edited or deleted by hand comes back.
    startAt = "hourly";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe publishDns;
      LoadCredential = [ "api_token:${dnsTokenFile}" ];
      # Cloudflare or the network may be unreachable at boot.
      Restart = "on-failure";
      RestartSec = "1min";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };
  };

  # Republish when the server writes its ticket, which it does on every start.
  systemd.paths.swarm-news-dns = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathChanged = ticketFile;
  };

  # Consistent daily online SQLite backup of /var/lib/renews-swarm (articles,
  # accounts, and runtime peer approvals) with 14-day retention.
  systemd.services.swarm-news-backup = {
    description = "Back up renews-swarm SQLite databases";
    after = [ "renews-iroh-${swarm.instanceName}.service" ];
    startAt = "daily";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe (
        pkgs.writeShellApplication {
          name = "swarm-news-backup";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.findutils
            pkgs.sqlite
          ];
          text = ''
            src=/var/lib/${instance.stateDirectory}
            dst=/var/backups/${instance.stateDirectory}
            day=$(date -u +%Y-%m-%d)
            tmp="$dst/.tmp-$day-$$"
            target="$dst/$day"
            mkdir -p "$dst" "$tmp"
            chmod 0700 "$dst" "$tmp"
            trap 'rm -rf "$tmp"' EXIT

            for db in news.db auth.db peers.db; do
              if [ -f "$src/$db" ]; then
                sqlite3 -readonly "$src/$db" ".timeout 10000" ".backup '$tmp/$db'"
              fi
            done
            rm -rf "$target"
            mv "$tmp" "$target"
            find "$dst" -mindepth 1 -maxdepth 1 -type d -name '20??-??-??' -mtime +14 -exec rm -rf {} +
          '';
        }
      );
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  assertions = [
    {
      assertion = swarm.serverEndpointId != null;
      message = "swarm-news: ${swarm.serverMachine} has no server endpoint id; run `clan vars generate ${swarm.serverMachine} --generator ${swarm.serverGenerator}`";
    }
    {
      assertion = host == swarm.serverMachine;
      message = "swarm-news: clients read the server key from ${swarm.serverMachine}'s vars, so the server must run there, not on ${host}";
    }
    {
      assertion = builtins.elem swarm.adminMachine members;
      message = "swarm-news: the admin machine ${swarm.adminMachine} must carry the ${swarm.tag} tag";
    }
  ]
  ++ map (member: {
    assertion = endpointIds.${member} != null;
    message = "swarm-news: ${member} has no endpoint id; run `clan vars generate ${member} --generator ${swarm.identityGenerator}`";
  }) members
  ++ map (account: {
    assertion = serviceEndpointIds.${account} != null;
    message = "swarm-news: service account ${account} has no endpoint id; run `clan vars generate ${
      swarm.serviceAccounts.${account}.machine
    } --generator ${swarm.serviceIdentityGenerator account}`";
  }) services;
}
