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
  pkgs = sys.pkgs;
  lib = pkgs.lib;
  kernelPackages = cfg.boot.kernelPackages;
  bin = lib.getBin;
  packages = {
    # onixos-host-base
    systemd = cfg.systemd.package;
    bash = pkgs.bashInteractive;
    coreutils = pkgs.coreutils;
    findutils = pkgs.findutils;
    gnugrep = pkgs.gnugrep;
    gnused = pkgs.gnused;
    "util-linux-bin" = pkgs.util-linux.bin;
    "util-linux-mount" = pkgs.util-linux.mount;
    "util-linux-login" = pkgs.util-linux.login;
    kmod = bin pkgs.kmod;
    "switch-to-configuration" = pkgs.switch-to-configuration-ng;
    "busybox-static" = pkgs.pkgsStatic.busybox;
    "glibc-locales" = cfg.i18n.glibcLocales;
    shadow = pkgs.shadow;
    "shadow-su" = pkgs.shadow.su;
    "linux-pam" = pkgs.linux-pam or pkgs.pam;
    dbus = pkgs.dbus;
    iproute2 = pkgs.iproute2;
    iputils = pkgs.iputils;
    procps = pkgs.procps;
    gnutar = pkgs.gnutar;
    gzip = pkgs.gzip;
    xz = bin pkgs.xz;
    less = pkgs.less;
    which = pkgs.which;
    "e2fsprogs-bin" = pkgs.e2fsprogs.bin;
    kernel = kernelPackages.kernel;
    "kernel-modules" = kernelPackages.kernel.modules;
    scx = pkgs.scx.full;
    borgbackup = pkgs.borgbackup;
    "linux-firmware" = pkgs.linux-firmware;
    "music-assistant" = pkgs.music-assistant;
    home-manager-activation = cfg.home-manager.users.brittonr.home.activationPackage;
    # onix-core's own packages (the onixpkgs overlay), and the gcc lib output the
    # mesh-llm start script puts on LD_LIBRARY_PATH.
    "arxiv-corpus" = pkgs.arxiv-corpus;
    laya = pkgs.laya;
    "mesh-llm" = pkgs.mesh-llm;
    "mesh-research" = pkgs.mesh-research;
    lib = pkgs.stdenv.cc.cc.lib;
    curl = pkgs.curl;
    # polkitd lives in the out output; the default is bin (pkaction, pkcheck, pkexec).
    polkit = pkgs.polkit.out;
    modemmanager = pkgs.modemmanager;
    logrotate = pkgs.logrotate;
    tzdata = pkgs.tzdata;
    cacert = pkgs.cacert;
    sops = pkgs.sops;
    getent = pkgs.getent;
    nftables = pkgs.nftables;
    docker = pkgs.docker;
    "docker-compose" = pkgs.docker-compose;
    "docker-buildx" = pkgs.docker-buildx;
    "docker-credential-helpers" = pkgs.docker-credential-helpers;
    dive = pkgs.dive;
    lazydocker = pkgs.lazydocker;
    ctop = pkgs.ctop;
    "podman-tui" = pkgs.podman-tui;
    prometheus = cfg.services.prometheus.package;
    loki = cfg.services.loki.package;
    grafana-alloy = cfg.services.alloy.package;
    onix-core-grafana = cfg.services.grafana.package;
    homepage-dashboard = cfg.services.homepage-dashboard.package;
    tailscalesd = pkgs.tailscalesd;
    "node-exporter" = pkgs.prometheus-node-exporter;
    "systemd-exporter" = pkgs.prometheus-systemd-exporter;
    blackbox = pkgs.prometheus-blackbox-exporter;
    nsncd = pkgs.nsncd;
    "nss-mdns" = pkgs.nssmdns;
    avahi = pkgs.avahi;
    networkmanager = pkgs.networkmanager;
    irqbalance = pkgs.irqbalance;
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
      public_keys = [ "aspen1-1:Q2UfPLC6y4NJ5xT1ZEjEttz/kNP5nMzTFfmrbi4vcql/q+MXKkIry4rk6J1J0xNHbe4JTee8gVeHY3ancXbsCA==" ];
    }
  ];
  packages = lib.mapAttrs (_: package: builtins.unsafeDiscardStringContext package.outPath) packages;
}
