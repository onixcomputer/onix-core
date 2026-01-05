# Cloud Hypervisor Host Configuration for RedoxOS Development
#
# This tag configures the host system for running RedoxOS in Cloud Hypervisor
# with TAP networking. It provides:
# - TAP interface (tap0) with host IP 172.16.0.1/24
# - NAT/masquerading for guest internet access
# - DHCP server (dnsmasq) for automatic guest IP configuration
# - IP forwarding enabled
# - cloud-hypervisor and related tools installed
#
# Usage:
#   1. Add "cloud-hypervisor-host" tag to machine in inventory/core/machines.nix
#   2. Rebuild NixOS: clan machines update <machine>
#   3. Run RedoxOS: nix run /path/to/redox#run-redox-cloud-hypervisor-net
#
# Guest configuration (automatic via DHCP):
#   IP: 172.16.0.2/24
#   Gateway: 172.16.0.1
#   DNS: 1.1.1.1, 8.8.8.8
#
{
  pkgs,
  lib,
  ...
}:

let
  # Network configuration - matches redox flake cloud-hypervisor-runners.nix
  tapInterface = "tap0";
  hostIp = "172.16.0.1";
  guestIp = "172.16.0.2";
  netmask = 24;
  guestMac = "52:54:00:12:34:56";
in
{
  # Users configuration - add current user to kvm group for VM access
  users.users.brittonr.extraGroups = [
    "kvm"
  ];

  # Network configuration for Cloud Hypervisor TAP networking
  networking = {
    # Enable IP forwarding for NAT
    nat = {
      enable = true;
      internalInterfaces = [ tapInterface ];
      # externalInterface set dynamically based on default route
    };

    # Configure TAP interface with static IP
    interfaces = {
      "${tapInterface}" = {
        ipv4.addresses = [
          {
            address = hostIp;
            prefixLength = netmask;
          }
        ];
      };
    };

    # Firewall configuration
    firewall = {
      enable = true;
      # Trust TAP interface for VM traffic (allows all traffic from tap0)
      trustedInterfaces = [ tapInterface ];
    };
  };

  # Systemd service to create and manage TAP interface
  systemd.services.cloud-hypervisor-network = {
    description = "Cloud Hypervisor TAP Network Setup";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    before = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStart = pkgs.writeScript "setup-cloud-hypervisor-tap" ''
        #!${pkgs.bash}/bin/bash
        set -e

        TAP_NAME="${tapInterface}"
        HOST_IP="${hostIp}"

        echo "Setting up Cloud Hypervisor TAP networking..."

        # Create TAP interface if it doesn't exist
        if ! ${pkgs.iproute2}/bin/ip link show "$TAP_NAME" &>/dev/null; then
          echo "Creating TAP interface $TAP_NAME..."
          ${pkgs.iproute2}/bin/ip tuntap add dev "$TAP_NAME" mode tap user brittonr
          echo "TAP interface created"
        else
          echo "TAP interface $TAP_NAME already exists"
        fi

        # Bring interface up (NixOS will configure the IP via networking.interfaces)
        ${pkgs.iproute2}/bin/ip link set "$TAP_NAME" up

        # Enable IP forwarding (redundant with NixOS boot.kernel.sysctl but ensures it's set)
        echo 1 > /proc/sys/net/ipv4/ip_forward

        echo "Cloud Hypervisor network setup complete"
        echo "  TAP interface: $TAP_NAME"
        echo "  Host IP: $HOST_IP/${toString netmask}"
        echo "  Guest should use: ${guestIp}/${toString netmask}"
        echo "  Gateway: $HOST_IP"
      '';

      ExecStop = pkgs.writeScript "teardown-cloud-hypervisor-tap" ''
        #!${pkgs.bash}/bin/bash

        TAP_NAME="${tapInterface}"

        if ${pkgs.iproute2}/bin/ip link show "$TAP_NAME" &>/dev/null; then
          echo "Removing TAP interface $TAP_NAME..."
          ${pkgs.iproute2}/bin/ip link delete "$TAP_NAME"
        fi
      '';
    };
  };

  # Enable IP forwarding at boot (use mkDefault to avoid conflicts with docker.nix)
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = lib.mkDefault 1;
    "net.ipv4.conf.all.forwarding" = lib.mkDefault 1;
  };

  # Ensure KVM modules are loaded
  boot.kernelModules = [
    "kvm-intel"
    "kvm-amd"
    "tun"
  ];

  # Install Cloud Hypervisor and related tools
  environment.systemPackages = with pkgs; [
    cloud-hypervisor
    iproute2
    dnsmasq
  ];

  # dnsmasq DHCP server for Cloud Hypervisor guests
  # Provides automatic IP configuration for RedoxOS
  services.dnsmasq = {
    enable = true;
    # CRITICAL: Prevents dnsmasq from modifying /etc/resolv.conf
    # Without this, NixOS points DNS to 127.0.0.1, but port=0 disables DNS
    resolveLocalQueries = false;
    settings = {
      # Only listen on TAP interface (don't conflict with system DNS)
      interface = tapInterface;
      # Use bind-dynamic instead of bind-interfaces to handle late-starting TAP
      bind-dynamic = true;
      except-interface = "lo";

      # Disable DNS server completely - DHCP only mode
      port = 0;

      # DHCP configuration
      dhcp-range = "${guestIp},${guestIp},12h";
      dhcp-host = "${guestMac},${guestIp}";
      dhcp-option = [
        "option:router,${hostIp}"
        "option:dns-server,1.1.1.1,8.8.8.8"
      ];
    };
  };

  # Ensure dnsmasq starts after TAP interface is created
  systemd.services.dnsmasq = {
    after = [ "cloud-hypervisor-network.service" ];
    wants = [ "cloud-hypervisor-network.service" ];
  };
}
