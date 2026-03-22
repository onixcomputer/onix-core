# Cloud Hypervisor Host — base networking for running cloud-hypervisor guests.
#
# Provides:
# - KVM kernel modules and tun device
# - IP forwarding and NAT
# - dnsmasq in DHCP-only mode (bind-dynamic, listens on all tap-* interfaces)
# - cloud-hypervisor and related tools
# - Legacy tap0 interface for RedoxOS development
#
# Per-VM TAP interfaces and DHCP reservations are added by the
# cloud-hypervisor-vm clan service module instances.
{
  pkgs,
  lib,
  ...
}:

let
  # Legacy RedoxOS TAP — kept for backward compat with redox flake.
  legacyTap = "tap0";
  hostIp = "172.16.0.1";
  netmask = 24;
  legacyGuestIp = "172.16.0.2";
  legacyGuestMac = "52:54:00:12:34:56";
in
{
  users.users.brittonr.extraGroups = [ "kvm" ];

  # --- Kernel ---

  boot.kernelModules = [
    "kvm-intel"
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
      # Legacy tap0 always included; service module adds per-VM taps via mkAfter.
      internalInterfaces = [ legacyTap ];
    };

    firewall = {
      enable = true;
      trustedInterfaces = [ legacyTap ];
    };

    # Legacy tap0 host-side IP.
    interfaces.${legacyTap} = {
      ipv4.addresses = [
        {
          address = hostIp;
          prefixLength = netmask;
        }
      ];
    };
  };

  # --- Legacy TAP setup (RedoxOS) ---

  systemd.services.cloud-hypervisor-network = {
    description = "Cloud Hypervisor TAP Network Setup (legacy tap0)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    before = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStart = pkgs.writeScript "setup-cloud-hypervisor-tap" ''
        #!${pkgs.bash}/bin/bash
        set -e
        if ! ${pkgs.iproute2}/bin/ip link show "${legacyTap}" &>/dev/null; then
          ${pkgs.iproute2}/bin/ip tuntap add dev "${legacyTap}" mode tap user brittonr
        fi
        ${pkgs.iproute2}/bin/ip link set "${legacyTap}" up
      '';

      ExecStop = pkgs.writeScript "teardown-cloud-hypervisor-tap" ''
        #!${pkgs.bash}/bin/bash
        if ${pkgs.iproute2}/bin/ip link show "${legacyTap}" &>/dev/null; then
          ${pkgs.iproute2}/bin/ip link delete "${legacyTap}"
        fi
      '';
    };
  };

  # --- Packages ---

  environment.systemPackages = with pkgs; [
    cloud-hypervisor
    iproute2
    dnsmasq
  ];

  # --- dnsmasq: DHCP-only for all TAP interfaces ---

  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      # bind-dynamic handles interfaces that appear after dnsmasq starts.
      bind-dynamic = true;
      except-interface = "lo";

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
