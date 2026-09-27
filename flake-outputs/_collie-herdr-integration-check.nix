# Check evaluated service values and generated files, not Nix source strings.
{
  pkgs,
  lib,
  desktopConfig,
  desktopHome,
  aspen3Home,
  aspen1Home,
  collie,
}:
let
  bridgePort = 8787;
  httpsPort = 443;
  service = desktopHome.systemd.user.services.collie;
  publication = desktopConfig.systemd.services.collie-serve;
  expectedEnvironmentFile = "%h/.config/herdr/plugins/config/herdr.collie/.env";
  expectedPublication = "/bin/tailscale serve --bg --https=${toString httpsPort} --set-path=/ ${toString bridgePort}";
  generatedPublication =
    pkgs.writeText "collie-serve.service"
      desktopConfig.systemd.units."collie-serve.service".text;
  envFile = desktopHome.xdg.configFile."herdr/plugins/config/herdr.collie/.env".source;
  legacyEnvFile = desktopHome.xdg.configFile."collie/.env".source;
  remoteService = desktopHome.systemd.user.services.collie-aspen3;
  remoteCommand = lib.concatStringsSep " " remoteService.Service.ExecStart;
  remoteSocketLink = desktopHome.xdg.configFile."herdr/sessions/aspen3/herdr.sock".source;
  desktopUid = desktopConfig.users.users.brittonr.uid;
  expectedRemoteSocket = "/run/user/${toString desktopUid}/collie-aspen3/herdr.sock";
  checks = [
    {
      name = "positive: bridge runs the packaged Bun entry point";
      passed = service.Service.ExecStart == [ "${pkgs.bun}/bin/bun run ${collie}/bridge/index.ts" ];
    }
    {
      name = "negative: bridge cannot start without its managed environment";
      passed = service.Service.EnvironmentFile == [ expectedEnvironmentFile ];
    }
    {
      name = "positive: bridge and controller share config and state";
      passed = lib.all (value: builtins.elem value service.Service.Environment) [
        "HERDR_SOCKET_PATH=%h/.config/herdr/herdr.sock"
        "HERDR_PLUGIN_CONFIG_DIR=%h/.config/herdr/plugins/config/herdr.collie"
        "HERDR_PLUGIN_STATE_DIR=%h/.local/state/collie"
      ];
    }
    {
      name = "negative: bridge has no default-target ordering cycle";
      passed = !(builtins.elem "default.target" (service.Unit.After or [ ]));
    }
    {
      name = "positive: host owns a bounded persistent HTTPS publication";
      passed =
        publication.serviceConfig.Type == "oneshot"
        && publication.serviceConfig.RemainAfterExit
        && publication.serviceConfig.Restart == "on-failure"
        && (publication.serviceConfig.User or "root") == "root"
        && builtins.isInt publication.startLimitIntervalSec
        && publication.startLimitIntervalSec > 0
        && publication.startLimitBurst > 0
        && builtins.elem "multi-user.target" publication.wantedBy
        && lib.hasSuffix expectedPublication publication.serviceConfig.ExecStart;
    }
    {
      name = "negative: publication cannot reset other Tailscale Serve routes";
      passed =
        !(lib.hasInfix "reset" publication.serviceConfig.ExecStart)
        && !(lib.hasInfix "funnel" publication.serviceConfig.ExecStart);
    }
    {
      name = "negative: no user service competes for publication";
      passed = !(desktopHome.systemd.user.services ? collie-serve);
    }
    {
      name = "negative: desktop deployment does not enable bridges on other hosts";
      passed =
        !(aspen3Home.systemd.user.services ? collie)
        && !(aspen1Home.systemd.user.services ? collie)
        && !(aspen3Home.xdg.configFile ? "herdr/plugins/config/herdr.collie/.env")
        && !(aspen1Home.xdg.configFile ? "herdr/plugins/config/herdr.collie/.env");
    }
    {
      name = "positive: desktop forwards the Aspen3 user API through a private runtime socket";
      passed =
        remoteService.Service.RuntimeDirectory == "collie-aspen3"
        && remoteService.Service.RuntimeDirectoryMode == "0700"
        && remoteService.Service.Restart == "always"
        && builtins.elem "default.target" remoteService.Install.WantedBy
        && lib.hasInfix "%t/collie-aspen3/herdr.sock:/home/brittonr/.config/herdr/herdr.sock" remoteCommand
        && lib.hasInfix "brittonr@aspen3.local" remoteCommand;
    }
    {
      name = "negative: remote transport keeps host trust and never forwards agent credentials";
      passed = lib.all (value: lib.hasInfix value remoteCommand) [
        "StrictHostKeyChecking=yes"
        "HostKeyAlias=aspen3.clan"
        "BatchMode=yes"
        "IdentitiesOnly=yes"
        "ForwardAgent=no"
        "ExitOnForwardFailure=yes"
        "StreamLocalBindMask=0177"
      ];
    }
    {
      name = "negative: no root tunnel, client-protocol socket, or default-target ordering cycle";
      passed =
        !(lib.hasInfix "root@" remoteCommand)
        && !(lib.hasInfix "herdr-client.sock" remoteCommand)
        && !(builtins.elem "default.target" (remoteService.Unit.After or [ ]));
    }
    {
      name = "negative: other hosts do not inherit the desktop's remote-session alias";
      passed =
        !(aspen3Home.systemd.user.services ? collie-aspen3)
        && !(aspen1Home.systemd.user.services ? collie-aspen3)
        && !(aspen3Home.xdg.configFile ? "herdr/sessions/aspen3/herdr.sock")
        && !(aspen1Home.xdg.configFile ? "herdr/sessions/aspen3/herdr.sock");
    }
    {
      name = "negative: no Tailscale operator role is required";
      passed = !(builtins.elem "--operator=brittonr" desktopConfig.services.tailscale.extraUpFlags);
    }
  ];
in
pkgs.runCommand "collie-integration" { } ''
  set -eu
  ${lib.concatMapStringsSep "\n" (check: ''
    if [ "${lib.boolToString check.passed}" != true ]; then
      echo ${lib.escapeShellArg check.name} >&2
      exit 1
    fi
  '') checks}

  cmp ${envFile} ${legacyEnvFile}
  test "$(readlink ${remoteSocketLink})" = '${expectedRemoteSocket}'
  ${pkgs.gnugrep}/bin/grep -Fxq 'COLLIE_MULTI_SESSION=1' ${envFile}
  ${pkgs.gnugrep}/bin/grep -Fxq 'COLLIE_REMOTE_SESSIONS=aspen3' ${envFile}
  ${pkgs.gnugrep}/bin/grep -Fxq 'COLLIE_PORT=${toString bridgePort}' ${envFile}
  ${pkgs.gnugrep}/bin/grep -Fxq 'COLLIE_HOST=127.0.0.1' ${envFile}
  ${pkgs.gnugrep}/bin/grep -Fxq 'COLLIE_TRUSTED_USER=brittonrobitzsch@gmail.com' ${envFile}
  ${pkgs.gnugrep}/bin/grep -Fxq 'COLLIE_PUBLIC_HOSTS=britton-desktop.bison-tailor.ts.net' ${envFile}
  if ${pkgs.gnugrep}/bin/grep -Eq '^COLLIE_(SKIP_SERVE|DEVICE_HEADER)=' ${envFile}; then
    echo 'negative: identity must come from the real Tailscale Serve proxy' >&2
    exit 1
  fi
  ${pkgs.gnugrep}/bin/grep -Fq 'Type=oneshot' ${generatedPublication}
  ${pkgs.gnugrep}/bin/grep -Fq '${expectedPublication}' ${generatedPublication}
  if ${pkgs.gnugrep}/bin/grep -Eq '^\[\[build\]\]|^id = "(update|uninstall)"' ${collie}/herdr-plugin.toml; then
    echo 'negative: the immutable plugin exposes installation mutations' >&2
    exit 1
  fi
  touch "$out"
''
