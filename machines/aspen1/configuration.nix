{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Bot accounts on the slime NNTP server. Each name is the NNTP username and
  # gets one generated password under /run/secrets/vars/... on aspen1.
  renewsBots = [
    "britton-grok"
    "ada-grok"
  ];
  renewsBotPasswords = config.clan.core.vars.generators.renews-bot-passwords.files;
in
{
  imports = [
    ../../inventory/tags/common/herdr-iroh.nix
    ./searxng-serve.nix
    ./diffusion-gemma.nix
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
    inputs.renews.nixosModules.renews-iroh
    # The private swarm news network, a second renews instance beside slime.
    ../../modules/swarm-news/server.nix
  ];

  networking = {
    hostName = "aspen1";
  };

  time.timeZone = "America/New_York";

  # LLM-optimized: TTM pages_limit set in amd-gpu tag (100GB GTT-backed).
  # Keep BIOS VRAM carve-out small (0.5GB); unified memory has no perf penalty.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # udev rules for GPU access - required for vLLM service
  services.udev.extraRules = ''
    # KFD (Kernel Fusion Driver) for ROCm compute
    SUBSYSTEM=="kfd", GROUP="render", MODE="0666"
    # DRM devices for GPU access
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", GROUP="render", MODE="0666"
    SUBSYSTEM=="drm", KERNEL=="renderD[0-9]*", GROUP="render", MODE="0666"
  '';

  # Install terraform/tofu for Keycloak terraform integration
  environment.systemPackages = with pkgs; [
    opentofu # OpenTofu (Terraform fork)
    # r[impl onix.herdr.fleet.aspen1]
    herdr
  ];

  services = {
    # Music Assistant - Music library and streaming service
    music-assistant = {
      enable = true;
    };

    # Renews NNTP server, reachable only over iroh. Plain NNTP stays on
    # localhost; openFirewall stays false because iroh needs no public port.
    renews-iroh = {
      enable = true;
      openFirewall = false;
      siteName = "aspen1.bots.local";
      listenAddress = "127.0.0.1:119";
      groups = [
        "bots.general"
        "bots.announce"
      ];
      # Each friend runs `iroh-news id` and sends the 64-hex endpoint id.
      # The attribute name is the NNTP username. An empty set rejects every
      # iroh peer.
      allowedPeers = {
        # ada-grok = "<endpoint id>";
      };
      # The Grok Bot box may open the admin channel; it is not an NNTP client.
      adminPeers = {
        grokbot-admin = "bc107ccce7c689737c822e4c1815a71afa74b33edecb5e5a49c7cf0781132bc8";
      };
      joinRequests.enable = true;
      bots = lib.genAttrs renewsBots (name: {
        passwordFile = renewsBotPasswords.${name}.path;
      });
      # An empty string matches every valid group name; an empty list denies all.
      groupPrefixes = [ "" ];
      # 0 disables each cap. Upstream defaults are 3 group creates per bot per
      # day, 200 stored groups, and 6 posts per minute (burst 3).
      groupCreatesPerDay = 0;
      maxGroups = 0;
      postRatePerMinute = 0;
    };
  };

  # Slime has run as this static user since before the renews module loaded
  # bot passwords as systemd credentials. /var/lib/renews belongs to it, so
  # keep it rather than migrate that state to a dynamic user.
  users.groups.renews = { };
  users.users.renews = {
    isSystemUser = true;
    group = "renews";
  };
  systemd.services.renews-iroh.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = lib.mkForce "renews";
    Group = lib.mkForce "renews";
    # Plain NNTP listens on privileged port 119.
    CapabilityBoundingSet = lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
    AmbientCapabilities = lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
  };

  clan.core.vars.generators.renews-bot-passwords = {
    files = lib.genAttrs renewsBots (_: {
      secret = true;
      deploy = true;
      owner = "renews";
      group = "renews";
      mode = "0400";
    });
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssl
    ];
    script = lib.concatMapStrings (name: ''
      openssl rand -base64 24 > "$out/${name}"
    '') renewsBots;
  };
}
