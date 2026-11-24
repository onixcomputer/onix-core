# Names and helpers shared by the swarm news server, its members, and the
# client. The server is `services.renews-iroh.instances.swarm` on aspen1.
# Members are the machines tagged `swarm-news`.
{ lib, self }:
let
  # Public clan vars of any machine, read the way nix-signing.nix discovers
  # signing keys. Null until `clan vars generate` has produced the file.
  publicVar =
    machine: generator: file:
    let
      path = "${self}/vars/per-machine/${machine}/${generator}/${file}/value";
    in
    if builtins.pathExists path then lib.fileContents path else null;
in
rec {
  tag = "swarm-news";
  serverMachine = "aspen1";
  # Its member identity is the only admin peer. Approving machines that have
  # no clan vars (britton-air, cproof-brittonr) happens from here.
  adminMachine = "britton-desktop";
  instanceName = "swarm";
  user = "brittonr";

  # The server listens only on aspen1's tailnet address, with the n0 relays
  # off. aspen1 publishes `_iroh-news.swarm.blr.dev` as a DNS-only TXT record
  # holding the server's ticket, which lists only that address. Members dial
  # `swarm.blr.dev` with the server endpoint id pinned as `server_id`, so
  # iroh-news refuses a TXT answer that names any other endpoint. They never
  # use the name's A record.
  dnsZone = "blr.dev";
  serverName = "swarm.${dnsZone}";
  discoveryName = "_iroh-news.${serverName}";
  serverTailnetAddress = "100.100.103.95";
  serverPort = 1119;
  # Clan generator holding a Cloudflare token that may edit DNS in every
  # zone: the cloudflare-brittonr tunnel's, which already runs on aspen1.
  dnsTokenGenerator = "cloudflare-cloudflare-brittonr";
  dnsTokenFile =
    generators:
    generators.${dnsTokenGenerator}.files.api_token.path
      or (throw "swarm-news: ${serverMachine} uses the ${dnsTokenGenerator} vars for ${serverName}, and only the cloudflare-brittonr tunnel declares them; keep that tunnel on ${serverMachine}");

  # The human-readable site, at https://swarm.blr.dev/. Port 443 on aspen1's
  # tailnet address belongs to Tailscale Serve (SearXNG), so britton-desktop
  # serves it: Tailscale already forwards that host's tailnet port 443 to its
  # Traefik. aspen1 publishes `swarm.blr.dev` as a DNS-only A record for the
  # site host's tailnet address.
  siteMachine = "britton-desktop";
  siteTailnetAddress = "100.110.43.11";
  siteUrl = "https://${serverName}/";

  identityGenerator = "swarm-news-identity";
  serverGenerator = "swarm-news-server";
  passwordGenerator = machine: "swarm-news-password-${machine}";

  endpointIdOf = machine: publicVar machine identityGenerator "endpoint-id";
  serverEndpointId = publicVar serverMachine serverGenerator "endpoint-id";

  # Accounts for services rather than machines, each hosted on one member
  # with its own endpoint key: Kiln's fleet service posts as `kiln`, apart
  # from the agents on its host. The server allowlists and enrolls them like
  # members.
  serviceAccounts = {
    kiln = {
      machine = "britton-desktop";
      owner = "kiln-fleet";
    };
  };
  serviceIdentityGenerator = account: "swarm-news-identity-${account}";
  serviceEndpointIdOf =
    account:
    publicVar serviceAccounts.${account}.machine (serviceIdentityGenerator account) "endpoint-id";

  # Machine names carrying the tag, from the shared `nclMachines` definitions.
  members =
    machines:
    lib.attrNames (lib.filterAttrs (_: machine: builtins.elem tag (machine.tags or [ ])) machines);

  # A 32-byte iroh endpoint key and its public id, written by iroh-news itself
  # so the key format is the one the client and server load.
  mkKeyGenerator =
    {
      pkgs,
      irohNews,
      owner,
    }:
    {
      files.secret-key = {
        inherit owner;
        mode = "0400";
      };
      files.endpoint-id.secret = false;
      runtimeInputs = [
        irohNews
        pkgs.coreutils
        pkgs.jq
      ];
      script = ''
        state="$(mktemp -d)"
        export HOME="$state"
        # The key must land in $state, not in a SecretSpec provider named by
        # the caller's environment.
        unset SECRETSPEC_PROVIDER SECRETSPEC_PROFILE
        iroh-news --state-dir "$state" id > "$state/id.json"
        cp "$state/secret_key" "$out/secret-key"
        jq -r .endpoint_id "$state/id.json" > "$out/endpoint-id"
      '';
    };

  # Declared on the member and on the server. clan requires shared generators
  # to match on every machine, apart from file owner, group, and mode.
  mkPasswordGenerator = pkgs: {
    share = true;
    files.password = {
      owner = user;
      mode = "0400";
    };
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      openssl rand -base64 24 > "$out/password"
    '';
  };
}
