{ pkgs, ... }:

{
  # MicroVM host configuration for running Cloud Hypervisor VMs

  # Enable KVM virtualization
  virtualisation.libvirtd.enable = false; # We're managing VMs directly, not through libvirt

  # Create microvm user for tap device ownership and configure users
  users = {
    users.microvm = {
      isSystemUser = true;
      group = "microvm";
      description = "MicroVM system user for TAP device ownership";
    };

    groups.microvm = { };

    # Add your user to kvm group for VM management without root
    users.brittonr.extraGroups = [
      "kvm"
      "microvm"
    ];
  };

  # Network configuration for MicroVMs
  networking = {
    # Enable IP forwarding for VM networking
    nat = {
      enable = true;
      internalInterfaces = [ "vm-br0" ];
      externalInterface = "eth0"; # Adjust to your main network interface
    };

    # Create a bridge for VMs
    bridges = {
      "vm-br0" = {
        interfaces = [ ];
      };
    };

    # Configure the bridge interface
    interfaces = {
      "vm-br0" = {
        ipv4.addresses = [
          {
            address = "192.168.100.1";
            prefixLength = 24;
          }
        ];
      };
    };

    # Enable DHCP server for VMs (optional, or use static IPs)
    firewall = {
      enable = true;
      # Allow VM traffic
      trustedInterfaces = [
        "vm-br0"
        "vm-net*"
        "tap*"
      ];
      # Allow DHCP and DNS for VMs
      allowedUDPPorts = [
        67
        68
        53
      ];
      allowedTCPPorts = [ 53 ];

      # Enable NAT for VM subnet
      extraCommands = ''
        iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -j MASQUERADE
        iptables -A FORWARD -i vm-br0 -j ACCEPT
        iptables -A FORWARD -o vm-br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
      '';

      extraStopCommands = ''
        iptables -t nat -D POSTROUTING -s 192.168.100.0/24 -j MASQUERADE 2>/dev/null || true
        iptables -D FORWARD -i vm-br0 -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -o vm-br0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
      '';
    };
  };

  # Systemd service to create TAP interfaces for MicroVMs
  systemd.services.microvm-network-setup = {
    description = "Setup TAP interfaces for MicroVMs";
    wantedBy = [ "multi-user.target" ];
    before = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeScript "setup-microvm-network" ''
        #!${pkgs.bash}/bin/bash
        set -e

        # Function to create a tap interface
        create_tap() {
          local tap_name=$1
          local tap_user=$2

          if ! ${pkgs.iproute2}/bin/ip link show "$tap_name" &>/dev/null; then
            echo "Creating TAP interface $tap_name for user $tap_user"
            ${pkgs.iproute2}/bin/ip tuntap add name "$tap_name" mode tap user "$tap_user"
            ${pkgs.iproute2}/bin/ip link set "$tap_name" up
            ${pkgs.iproute2}/bin/ip link set "$tap_name" master vm-br0
          else
            echo "TAP interface $tap_name already exists"
          fi
        }

        # Create TAP interfaces for MicroVMs
        # These match the IDs in the microvm flake configuration
        create_tap "vm-net0" "microvm"
        create_tap "vm-net1" "microvm"

        # Create additional TAP interfaces if needed (for multiple VMs)
        for i in {2..10}; do
          create_tap "vm-net$i" "microvm"
        done

        echo "MicroVM network setup complete"
      '';

      ExecStop = pkgs.writeScript "teardown-microvm-network" ''
        #!${pkgs.bash}/bin/bash

        # Remove TAP interfaces
        for i in {0..10}; do
          tap_name="vm-net$i"
          if ${pkgs.iproute2}/bin/ip link show "$tap_name" &>/dev/null; then
            echo "Removing TAP interface $tap_name"
            ${pkgs.iproute2}/bin/ip link delete "$tap_name"
          fi
        done
      '';
    };
  };

  # Optional: DHCP server for VMs
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "vm-br0";
      bind-interfaces = true;
      dhcp-range = "192.168.100.10,192.168.100.250,12h";
      dhcp-option = [
        "option:router,192.168.100.1"
        "option:dns-server,192.168.100.1"
      ];
      # Static leases can be configured here based on MAC addresses
      dhcp-host = [
        # Example: "02:00:00:00:00:01,192.168.100.10,worker-vm-1"
      ];
      no-resolv = true;
      server = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      cache-size = 150;
    };
  };

  # Install useful tools for VM management
  environment.systemPackages = with pkgs; [
    cloud-hypervisor
    virtiofsd
    socat # For communicating with VM sockets
    bridge-utils # Bridge management tools
    iproute2 # Network configuration tools
    tmux # For managing VM sessions
    jq # For processing VM API responses
  ];

  # Boot configuration for VMs
  boot = {
    # Ensure KVM module is loaded
    kernelModules = [
      "kvm-intel"
      "kvm-amd"
    ];

    # Kernel parameters for better VM performance
    kernelParams = [
      "intel_iommu=on" # For Intel CPUs
      "amd_iommu=on" # For AMD CPUs
      "iommu=pt" # Pass-through mode for better performance
      "hugepages=128" # Reserve huge pages for VMs (optional)
    ];

    # Enable huge pages for better VM performance (optional)
    kernel.sysctl = {
      "vm.nr_hugepages" = 128; # Number of 2MB huge pages
    };
  };
}
