# Producer (Nix, offline): the package index aspen2's OnixOS host build consumes
# (onixos-host-package-index-v1, onixos/host/aspen2-packages.json). Every package name
# the host modules declare maps to the exact store path aspen2's NixOS configuration
# uses, so the host runs the same binaries; consuming the index runs no Nix.
#
#   nix eval --json --impure --expr \
#     'import ./onixos/host/packages.nix { self = builtins.getFlake "git+file://…?rev=…"; }'
{ self }:
let
  sys = self.nixosConfigurations.aspen2;
  cfg = sys.config;
  inherit (sys) pkgs;
  inherit (pkgs) lib;
  kernelPackages = cfg.boot.kernelPackages;
  bin = lib.getBin;
  packages = {
    # onixos-host-base
    systemd = cfg.systemd.package;
    bash = pkgs.bashInteractive;
    inherit (pkgs) coreutils;
    inherit (pkgs) findutils;
    inherit (pkgs) gnugrep;
    inherit (pkgs) gnused;
    "util-linux-bin" = pkgs.util-linux.bin;
    "util-linux-mount" = pkgs.util-linux.mount;
    "util-linux-login" = pkgs.util-linux.login;
    kmod = bin pkgs.kmod;
    "switch-to-configuration" = pkgs.switch-to-configuration-ng;
    "busybox-static" = pkgs.pkgsStatic.busybox;
    "glibc-locales" = cfg.i18n.glibcLocales;
    inherit (pkgs) shadow;
    "shadow-su" = pkgs.shadow.su;
    "linux-pam" = pkgs.linux-pam or pkgs.pam;
    inherit (pkgs) dbus;
    inherit (pkgs) iproute2;
    inherit (pkgs) iputils;
    inherit (pkgs) procps;
    inherit (pkgs) gnutar;
    inherit (pkgs) gzip;
    xz = bin pkgs.xz;
    inherit (pkgs) less;
    inherit (pkgs) which;
    "e2fsprogs-bin" = pkgs.e2fsprogs.bin;
    inherit (kernelPackages) kernel;
    "kernel-modules" = kernelPackages.kernel.modules;
    scx = pkgs.scx.full;
    inherit (pkgs) borgbackup;
    "linux-firmware" = pkgs.linux-firmware;
    inherit (pkgs) sudo;
    inherit (pkgs) fontconfig;
    "fontconfig-data" = pkgs.fontconfig.out;
    "apparmor-init" = pkgs.apparmor-init;
    "apparmor-parser" = pkgs.apparmor-parser;
    "apparmor-utils" = pkgs.apparmor-utils;
    "music-assistant" = pkgs.music-assistant;
    home-manager-activation = cfg.home-manager.users.brittonr.home.activationPackage;
    # onix-core's own packages (the onixpkgs overlay), and the gcc lib output the
    # mesh-llm start script puts on LD_LIBRARY_PATH.
    "arxiv-corpus" = pkgs.arxiv-corpus;
    inherit (pkgs) laya;
    "mesh-llm" = pkgs.mesh-llm;
    "mesh-research" = pkgs.mesh-research;
    lib = pkgs.stdenv.cc.cc.lib;
    inherit (pkgs) curl;
    # polkitd lives in the out output; the default is bin (pkaction, pkcheck, pkexec).
    polkit = pkgs.polkit.out;
    inherit (pkgs) modemmanager;
    inherit (pkgs) logrotate;
    inherit (pkgs) tzdata;
    inherit (pkgs) cacert;
    inherit (pkgs) sops;
    inherit (pkgs) getent;
    inherit (pkgs) nftables;
    inherit (pkgs) docker;
    "docker-compose" = pkgs.docker-compose;
    "docker-buildx" = pkgs.docker-buildx;
    "docker-credential-helpers" = pkgs.docker-credential-helpers;
    inherit (pkgs) dive;
    inherit (pkgs) lazydocker;
    inherit (pkgs) ctop;
    "podman-tui" = pkgs.podman-tui;
    prometheus = cfg.services.prometheus.package;
    loki = cfg.services.loki.package;
    grafana-alloy = cfg.services.alloy.package;
    onix-core-grafana = cfg.services.grafana.package;
    homepage-dashboard = cfg.services.homepage-dashboard.package;
    inherit (pkgs) tailscalesd;
    "node-exporter" = pkgs.prometheus-node-exporter;
    "systemd-exporter" = pkgs.prometheus-systemd-exporter;
    blackbox = pkgs.prometheus-blackbox-exporter;
    inherit (pkgs) nsncd;
    "nss-mdns" = pkgs.nssmdns;
    inherit (pkgs) avahi;
    inherit (pkgs) networkmanager;
    inherit (pkgs) irqbalance;
    "kitty-terminfo" = pkgs.kitty.terminfo;
    "wezterm-terminfo" = pkgs.wezterm.terminfo;
    # sshd
    openssh = cfg.services.openssh.package;
    # tailscale
    tailscale = cfg.services.tailscale.package;
    jq = bin pkgs.jq;
    # host-common
    fish = cfg.programs.fish.package or pkgs.fish;
  };
in
{
  schema = "onixos-host-package-index-v1";
  caches = [
    {
      url = "https://cache.nixos.org";
      public_keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
    }
    {
      # aspen1's Harmonia cache over the tailnet. AGENTS.md prescribes the IP so
      # nix-daemon does not depend on mDNS; signature verification still applies.
      url = "http://100.100.103.95:5000";
      public_keys = [ "aspen1-1:hdbOqMbh1N/jLuqHVErDlrI7Wh9Cd/htzF7HUWYjQRc=" ];
    }
  ];
  packages = lib.mapAttrs (_: package: builtins.unsafeDiscardStringContext package.outPath) packages;
}
