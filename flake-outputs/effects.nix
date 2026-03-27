# Scheduled effects via buildbot-nix's hercules-ci-compatible API.
#
# flake-update: runs 2x/week (Mon+Thu 04:00 UTC), updates flake.lock,
# pushes a branch, opens a PR. buildbot evaluates the PR, merge-when-green
# merges it. Full automation loop.
{ inputs, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  hci-effects = inputs.buildbot-nix.inputs.hercules-ci-effects.lib.withPkgs pkgs;
in
{
  herculesCI = _args: {
    onSchedule = {
      flake-update = {
        when = {
          hour = [ 4 ];
          minute = 0;
          dayOfWeek = [
            "Mon"
            "Thu"
          ];
        };
        outputs.effects.update = hci-effects.flakeUpdate {
          gitRemote = "https://github.com/onixcomputer/onix-core.git";
          user = "x-access-token";
          updateBranch = "auto/flake-update";
          forgeType = "github";
          createPullRequest = true;
          pullRequestTitle = "flake.lock: scheduled update";
          pullRequestBody = ''
            Automated flake input update (Mon/Thu 04:00 UTC).

            buildbot will evaluate and build all machine configs.
            merge-when-green will auto-merge if CI passes.
          '';
          baseMergeMethod = "reset";
          baseMergeBranch = "main";
          flakes = {
            "." = {
              commitSummary = "flake.lock: scheduled update";
            };
          };
        };
      };
    };
  };
}
