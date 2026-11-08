# Producer (Nix, offline): the package index aspen2's OnixOS host build consumes
# (onixos-host-package-index-v1, onixos/host/aspen2-packages.json). Every package name
# the host modules declare maps to the exact store path aspen2's NixOS configuration
# uses, so the host runs the same binaries; consuming the index runs no Nix.
#
#   nix eval --json --impure --expr \
#     'import ./onixos/host/packages.nix { self = builtins.getFlake "git+file://…?rev=…"; }'
{
  self,
  realise ? false,
}:
let
  sys = self.nixosConfigurations.aspen2;
  cfg = sys.config;
  hmSystem = sys.extendModules {
    modules = [ (import ./home-manager-profile-filter.nix) ];
  };
  hmCfg = hmSystem.config;
  inherit (sys) pkgs;
  inherit (pkgs) lib;
  kernelPackages = cfg.boot.kernelPackages;
  musicAssistant = cfg.services.music-assistant.package.override {
    inherit (cfg.services.music-assistant) providers;
  };
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
    "e2fsprogs-static-bin" = pkgs.pkgsStatic.e2fsprogs.bin;
    inherit (pkgs) dosfstools;
    "microcode-amd" = cfg.hardware.cpu.amd.microcodePackage;
    "dropbear-static" = pkgs.pkgsStatic.dropbear;
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
    "music-assistant" = musicAssistant;
    "music-assistant-pythonpath-env" =
      pkgs.writeText "music-assistant-pythonpath.env" "PYTHONPATH=${musicAssistant.pythonPath}\n";
    inherit (pkgs) lsof;
    home-manager-activation = import ./home-manager-activation.nix {
      inherit pkgs;
      activationPackage = hmCfg.home-manager.users.brittonr.home.activationPackage;
    };
    home-manager-profile = {
      outPath = hmCfg.environment.etc."profiles/per-user/brittonr".source;
    };
    system-tools = import ./retained-packages.nix { inherit lib pkgs cfg; };
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
    inherit (pkgs) zram-generator;
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
    inherit (pkgs) wpa_supplicant;
    inherit (pkgs) wireless-regdb;
    inherit (pkgs) cni-plugins;
    inherit (pkgs) catatonit;
    "skopeo-policy" = pkgs.skopeo.policy;
    inherit (pkgs) kmod-debian-aliases;
    inherit (pkgs) kmod-blacklist-ubuntu;
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
    inherit (pkgs) direnv;
    inherit (pkgs) bash-completion;
    # Retained GPU monitoring and FHS compatibility. Reuse the configured
    # nixpkgs outputs rather than constructing another runtime library set.
    "graphics-drivers" = {
      outPath = cfg.systemd.tmpfiles.settings.graphics-driver."/run/opengl-driver"."L+".argument;
    };
    "graphics-drivers-32bit" = {
      outPath = cfg.systemd.tmpfiles.settings.graphics-driver."/run/opengl-driver-32"."L+".argument;
    };
    "rocm-smi" = pkgs.rocmPackages.rocm-smi;
    "rocm-clr-icd" = pkgs.rocmPackages.clr.icd;
    inherit (pkgs) vulkan-validation-layers;
    inherit (pkgs) libdrm;
    rocminfo = pkgs.rocmPackages.rocminfo;
    inherit (pkgs) clinfo;
    inherit (pkgs) radeontop;
    "nvtop-amd" = pkgs.nvtopPackages.amd;
    inherit (pkgs) btop;
    inherit (pkgs) vulkan-tools;
    "nix-ld" = cfg.programs.nix-ld.package;
    "nix-ld-libraries" =
      lib.findFirst (package: (package.name or "") == "ld-library-path")
        (throw "aspen2 package index: configured nix-ld library set is missing")
        cfg.environment.systemPackages;
    envfs = cfg.services.envfs.package;
    "envfs-fallback-path" = {
      outPath = lib.removePrefix "fallback-path=" (
        lib.findFirst (option: lib.hasPrefix "fallback-path=" option)
          (throw "aspen2 package index: configured envfs fallback path is missing")
          cfg.fileSystems."/usr/bin".options
      );
    };
    "vllm-cluster-env" = pkgs.writeShellApplication {
      name = "vllm-cluster-env";
      runtimeInputs = [ pkgs.coreutils ];
      text = builtins.readFile ../../inventory/tags/vllm-cluster-env.sh;
    };
  };
  index = {
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
    packages = lib.mapAttrs (_: package: package.outPath) packages;
  };
in
# Realizing this producer-only derivation builds every selected package through
# its string context. The target consumes the index and signed cache objects.
if realise then
  pkgs.writeText "onixos-aspen2-package-index.json" (builtins.toJSON index)
else
  index // { packages = lib.mapAttrs (_: builtins.unsafeDiscardStringContext) index.packages; }
