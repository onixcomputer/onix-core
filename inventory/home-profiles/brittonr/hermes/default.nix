# Install the official Hermes Agent (Nous Research) for brittonr on aspen3.
#
# r[impl onix.hermes_agent.install]
# r[impl onix.hermes_agent.install.desktop]
# r[impl onix.hermes_agent.install.cli]
#
# The upstream Home Manager module separates installation from daemons.
# `programs.hermes-agent.enable` adds the `hermes` CLI to home.packages and
# exports HERMES_HOME. `programs.hermes-agent.desktop.enable` adds the
# Hermes Desktop Electron application with a Linux XDG launcher entry whose
# wrapper carries HERMES_HOME itself (a GUI menu reads no shell profile).
#
# The service layer stays disabled on purpose: brittonr keeps the standard
# interactive first-run setup (`hermes setup --portal`), and the desktop
# starts its own loopback backend. A gateway/backend and Nix-declared
# `services.hermes-agent` settings are follow-on work.
{ inputs, ... }:
{
  imports = [ inputs.hermes-agent.homeManagerModules.default ];

  programs.hermes-agent = {
    enable = true;
    desktop.enable = true;
  };
}
