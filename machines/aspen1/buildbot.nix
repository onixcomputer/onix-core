# Buildbot worker on aspen1.
#
# Connects to the master on aspen2. Builds are distributed across both
# aspen machines for parallel capacity. Build outputs get pushed to
# aspen2's harmonia cache via the master's postBuildSteps.
{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.buildbot-nix.nixosModules.buildbot-worker
  ];

  # Same shared generator as on aspen2 — clan vars deduplicates via share = true.
  # Both machines need the definition so the module system can resolve the path.
  clan.core.vars.generators.buildbot-worker-aspen1 = {
    share = true;
    files.password = { };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      head -c 32 /dev/urandom | base64 | tr -d '\n' > $out/password
    '';
  };

  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = config.clan.core.vars.generators.buildbot-worker-aspen1.files.password.path;
    masterUrl = "tcp:host=aspen2:port=9989";
    workers = 16;
  };
}
