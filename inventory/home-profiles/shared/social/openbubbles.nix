# Installs the local OpenBubbles package instead of the legacy BlueBubbles
# client. BlueBubbles needs an always-on companion Mac server; OpenBubbles is
# serverless and talks to Apple directly. The bundle is an x86_64-linux Flutter
# app, and this profile is only enabled on x86_64-linux machines.
{
  pkgs,
  ...
}:
{
  home.packages = [
    (pkgs.callPackage ../../../../pkgs/openbubbles { })
  ];
}
