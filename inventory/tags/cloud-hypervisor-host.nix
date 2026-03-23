# Cloud Hypervisor Host — base networking for running cloud-hypervisor guests.
#
# Provides:
# - KVM kernel modules and tun device
# - br-chv bridge with 172.16.0.1/24 gateway (all VM TAPs attach here)
# - IP forwarding and NAT through the bridge
# - dnsmasq in DHCP-only mode on the bridge
# - cloud-hypervisor and related tools
# - Legacy tap0 interface for RedoxOS development (also bridged)
#
# Per-VM TAP interfaces and DHCP reservations are added by the
# cloud-hypervisor-vm clan service module instances.
{
  pkgs,
  lib,
  ...
}:

let
  bridge = "br-chv";
  hostIp = "172.16.0.1";
  netmask = 24;

  # Legacy RedoxOS TAP — kept for backward compat with redox flake.
  legacyTap = "tap0";
  legacyGuestIp = "172.16.0.2";
  legacyGuestMac = "52:54:00:12:34:56";
in
{
  users.users.brittonr.extraGroups = [ "kvm" ];

  # --- Kernel ---

  # Only kvm-amd — all current cloud-hypervisor hosts are AMD.
  # Loading kvm-intel on AMD produces a noisy "VMX not supported" error.
  boot.kernelModules = [
    "kvm-amd"
    "tun"
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = lib.mkDefault 1;
    "net.ipv4.conf.all.forwarding" = lib.mkDefault 1;
  };

  # --- NAT ---

  networking = {
    nat = {
      enable = true;
      internalInterfaces = [ bridge ];
    };

    firewall = {
      enable = true;
      trustedInterfaces = [ bridge ];
    };
  };

  # --- Bridge + legacy TAP setup ---

  systemd.services.cloud-hypervisor-network = {
    description = "Cloud Hypervisor bridge and legacy TAP setup";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    before = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStart =
        let
          script = pkgs.writeShellApplication {
            name = "setup-cloud-hypervisor-network";
            runtimeInputs = [
              pkgs.iproute2
              pkgs.gnugrep
            ];
            text = ''
              # Create the bridge if it doesn't exist.
              if ! ip link show "${bridge}" &>/dev/null; then
                ip link add name "${bridge}" type bridge
              fi
              ip link set "${bridge}" up

              # Assign the gateway IP to the bridge (shared by all VMs).
              if ! ip addr show "${bridge}" | grep -q '${hostIp}/${toString netmask}'; then
                ip addr add ${hostIp}/${toString netmask} dev "${bridge}"
              fi

              # Legacy RedoxOS TAP — attach to the bridge.
              if ! ip link show "${legacyTap}" &>/dev/null; then
                ip tuntap add dev "${legacyTap}" mode tap user brittonr
              fi
              ip link set "${legacyTap}" master "${bridge}"
              ip link set "${legacyTap}" up
            '';
          };
        in
        lib.getExe script;

      ExecStop =
        let
          script = pkgs.writeShellApplication {
            name = "teardown-cloud-hypervisor-network";
            runtimeInputs = [ pkgs.iproute2 ];
            text = ''
              if ip link show "${legacyTap}" &>/dev/null; then
                ip link delete "${legacyTap}"
              fi
              if ip link show "${bridge}" &>/dev/null; then
                ip link delete "${bridge}"
              fi
            '';
          };
        in
        lib.getExe script;
    };
  };

  # --- Packages ---

  environment.systemPackages = with pkgs; [
    cloud-hypervisor
    iproute2
    dnsmasq
  ];

  # --- dnsmasq: DHCP-only on the bridge ---

  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      # Listen only on the bridge — not on physical interfaces.
      interface = bridge;
      bind-dynamic = true;

      # Disable DNS — DHCP only.
      port = 0;

      # DHCP range covers the whole 172.16.0.0/24 subnet.
      # Per-host reservations pin specific MACs to IPs.
      dhcp-range = "172.16.0.2,172.16.0.254,12h";

      # Legacy RedoxOS reservation.
      dhcp-host = [ "${legacyGuestMac},${legacyGuestIp}" ];

      dhcp-option = [
        "option:router,${hostIp}"
        "option:dns-server,1.1.1.1,8.8.8.8"
      ];
    };
  };

  systemd.services.dnsmasq = {
    after = [ "cloud-hypervisor-network.service" ];
    wants = [ "cloud-hypervisor-network.service" ];
  };
}
