# Collie: a phone PWA for managing a Herdr agent herd over Tailscale.
#
# Upstream is umakers/collie-herdr, a fork of AltanS/collie. Collie is a Herdr
# plugin (thin launcher) plus a Bun/TypeScript bridge that must run as a
# supervised user service and be published on the tailnet.
#
# Build strategy (see UPSTREAM.md): the Vite/React web UI is built with Bun and
# vendored into ./dist, and both are pinned at one immutable upstream revision.
# The frontend dependency fetch failed in the sandbox during installation.
# Vendoring that build keeps package builds offline. Bun runs the pinned bridge.
#
# Home Manager owns the bridge. The host owns Tailscale Serve publication.
# The managed controller cannot rebuild packages or change either service owner.
{
  lib,
  bash,
  bun,
  coreutils,
  fetchFromGitHub,
  formats,
  git,
  gnugrep,
  gnused,
  jq,
  procps,
  stdenvNoCC,
  systemd,
  tailscale,
}:
let
  version = "0.24.1";
  regularFileMode = "444";
  executableMode = "755";
  src = fetchFromGitHub {
    owner = "umakers";
    repo = "collie-herdr";
    rev = "b2d2803b3f691e9abca74f3f15bbc37307a2026e";
    hash = "sha256-SSfYyrVanmmKNKxazT0HYkcDTSWGODH4ya8L5aPpYcU=";
  };

  # Everything collie-ctl.sh and the bridge need at runtime. The control script
  # shells out to bun / tailscale / systemctl and spawns children that must find
  # those tools on PATH, so the wrapper pins them instead of depending on the
  # caller's environment (Herdr action spawns a minimal env).
  runtimePath = lib.makeBinPath [
    bash
    bun
    coreutils
    git
    gnugrep
    gnused
    jq
    procps
    systemd
    tailscale
  ];
  pluginId = "herdr.collie";
  pluginManifest = (formats.toml { }).generate "collie-herdr-plugin.toml" {
    id = pluginId;
    name = "Collie";
    inherit version;
    min_herdr_version = "0.7.0";
    description = "Mobile Herdr UI with Nix-owned installation and publication";
    platforms = [ "linux" ];
    actions =
      map
        (
          action:
          action
          // {
            contexts = [ "workspace" ];
            command = [
              "${bash}/bin/bash"
              "scripts/collie-ctl.sh"
              action.id
            ];
          }
        )
        [
          {
            id = "start";
            title = "Start web bridge";
          }
          {
            id = "stop";
            title = "Stop web bridge";
          }
          {
            id = "restart";
            title = "Restart web bridge";
          }
          {
            id = "url";
            title = "Show bridge URL";
          }
          {
            id = "status";
            title = "Bridge status";
          }
          {
            id = "version";
            title = "Show version";
          }
        ];
  };
in
stdenvNoCC.mkDerivation {
  pname = "collie-herdr";
  inherit version src;

  patches = [ ./remote-sessions.patch ];
  postPatch = ''
    cp ${./remote-sessions.ts} bridge/remote-sessions.ts
    cp ${./remote-sessions.test.ts} bridge/remote-sessions.test.ts
  '';

  installPhase = ''
    runHook preInstall
    install -Dm${regularFileMode} ${pluginManifest} $out/herdr-plugin.toml
    install -Dm${regularFileMode} LICENSE $out/share/licenses/collie-herdr/LICENSE
    cp -R bridge $out/bridge
    cp -R scripts $out/scripts
    mv $out/scripts/collie-ctl.sh $out/scripts/collie-ctl-upstream.sh
    install -Dm${executableMode} ${./managed-ctl.sh} $out/scripts/collie-ctl.sh
    substituteInPlace $out/scripts/collie-ctl.sh \
      --replace-fail '#!/usr/bin/env bash' '#!${bash}/bin/bash' \
      --replace-fail '@bash@' '${bash}' \
      --replace-fail '@runtimePath@' '${runtimePath}' \
      --replace-fail '@systemctl@' '${systemd}/bin/systemctl'
    # Vendored, prebuilt UI; see UPSTREAM.md for regeneration.
    mkdir -p $out/web
    cp -R ${./dist} $out/web/dist
    test -f $out/web/dist/index.html
    install -Dm${regularFileMode} systemd/collie.service $out/systemd/collie.service
    install -Dm${regularFileMode} package.json bun.lock bunfig.toml tsconfig.json .npmrc $out/
    install -Dm${regularFileMode} web/package.json $out/web/package.json
    chmod +x $out/scripts/*.sh $out/scripts/*.ts

    # Direct CLI calls and Herdr actions share the same managed controller.
    mkdir -p $out/bin
    cat > $out/bin/collie-ctl <<EOF
    #!${bash}/bin/bash
    exec "$out/scripts/collie-ctl.sh" "\$@"
    EOF
    chmod +x $out/bin/collie-ctl
    runHook postInstall
  '';

  passthru = {
    inherit pluginId version;
  };

  meta = {
    description = "Phone web UI for a Herdr agent herd, served over Tailscale";
    homepage = "https://github.com/umakers/collie-herdr";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
