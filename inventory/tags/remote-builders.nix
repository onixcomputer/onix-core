{
  lib,
  config,
  pkgs,
  wasm,
  nclMachines,
  ...
}:
let
  allMachines = nclMachines;
  builderData = wasm.evalNickelFile ./builder-targets.ncl;
  builderKeyPath = config.clan.core.vars.generators.nix-builder-ssh.files."id_ed25519".path;
  hostname = config.networking.hostName;
  sshHostKeys = import ../../lib/ssh-host-keys.nix { inherit lib; };

  getSshHost =
    sshHost:
    let
      parts = builtins.match "([^@]+@)?(.+)" sshHost;
    in
    if parts == null then sshHost else builtins.elemAt parts 1;

  # Read each generated SSH host public key through the shared pure accessor.
  getHostKey = sshHostKeys.readPublicKey;

  # Builder targets from Nickel (validated against machine registry).
  builderTargetNames = builtins.map (t: t.name) builderData.targets;
  builderTargetsByName = builtins.listToAttrs (
    builtins.map (t: {
      inherit (t) name;
      value = t;
    }) builderData.targets
  );

  consumerMayUseTarget =
    target: !(target ? allowedConsumers) || builtins.elem hostname target.allowedConsumers;

  # r[impl onix.remote_builder.routing.selection]
  selectBuilderHost =
    target: machine:
    let
      explicitSshHost = target.sshHost or null;
      lanAddress = machine.addresses.lan or null;
    in
    if explicitSshHost != null then
      explicitSshHost
    else if lanAddress != null then
      lanAddress
    else
      machine.name;

  builderMachines = lib.filterAttrs (
    name: _:
    builtins.elem name builderTargetNames
    && name != hostname
    && consumerMayUseTarget builderTargetsByName.${name}
  ) allMachines;

  # Build the nix.buildMachines list from typed target metadata and inventory.
  # An explicit SSH host takes priority over the LAN address and machine name.
  allBuildMachines = lib.mapAttrsToList (
    name: m:
    let
      target = builderTargetsByName.${name};
      sshHostName = selectBuilderHost target m;
    in
    {
      protocol = "ssh-ng";
      hostName = sshHostName;
      inherit (target)
        systems
        maxJobs
        speedFactor
        sshUser
        supportedFeatures
        ;
      sshKey = builderKeyPath;
    }
  ) builderMachines;

  # r[impl onix.remote_builder.routing.host_key]
  # Generate SSH known hosts from inventory + vars.
  knownHostEntries = lib.mapAttrs' (
    name: m:
    let
      lan = m.addresses.lan or null;
      target = builderTargetsByName.${name} or null;
      explicitSshHost = if target == null then null else target.sshHost or null;
      hostKey = getHostKey name;
      hostNames = lib.unique (
        lib.optional (explicitSshHost != null) explicitSshHost
        ++ lib.optional (lan != null) lan
        ++ lib.optional (name != (if lan != null then lan else "")) name
      );
    in
    lib.nameValuePair name {
      inherit hostNames;
      publicKey = hostKey;
    }
  ) (lib.filterAttrs (name: _: getHostKey name != null) allMachines);

  explicitBuilderHosts = builtins.map (target: target.sshHost) (
    builtins.filter (target: target ? sshHost) builderData.targets
  );

  rootDeployHosts = lib.unique (
    explicitBuilderHosts
    ++ lib.flatten (
      lib.mapAttrsToList (
        name: m:
        let
          lan = m.addresses.lan or null;
          targetHost = m.deploy.targetHost or null;
        in
        lib.optionals (name != hostname) (
          lib.optional (targetHost != null) (getSshHost targetHost)
          ++ lib.optional (lan != null) lan
          ++ [ name ]
        )
      ) allMachines
    )
  );
in
{
  clan.core.vars.generators.nix-builder-ssh = {
    files."id_ed25519" = { };
    files."id_ed25519.pub".secret = false;
    runtimeInputs = [ pkgs.openssh ];
    script = ''
      ssh-keygen -t ed25519 -N "" -C "nix-builder@${hostname}" -f "$out/id_ed25519"
    '';
  };

  nix = {
    distributedBuilds = lib.mkDefault true;
    settings.builders-use-substitutes = lib.mkDefault true;
    buildMachines = allBuildMachines;
  };

  programs.ssh = {
    extraConfig = lib.mkAfter ''
      Match localuser root host ${lib.concatStringsSep "," rootDeployHosts}
        IdentityAgent none
        IdentityFile ${builderKeyPath}
        IdentitiesOnly yes
        StrictHostKeyChecking accept-new
    '';
    knownHosts = knownHostEntries;
  };
}
