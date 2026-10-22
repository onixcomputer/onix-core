# buildbot-nix hands makeWrapper `--prefix PATH : <bin>` as a single argument.
# Python derivations now default to structuredAttrs, which keeps that string
# whole, so makeWrapper rejects it. Pass the words separately. Both roles import
# this file; the module system includes it once per machine.
{
  lib,
  options,
  pkgs,
  ...
}:
{
  services.buildbot-nix.packages.buildbot-effects =
    options.services.buildbot-nix.packages.buildbot-effects.default.overridePythonAttrs
      {
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [ pkgs.bubblewrap ])
        ];
      };
}
