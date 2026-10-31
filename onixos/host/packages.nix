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
    polkit = pkgs.polkit;
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
  ];
  packages = lib.mapAttrs (_: package: builtins.unsafeDiscardStringContext package.outPath) packages;
}
