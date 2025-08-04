{ inputs, ... }:
{
  instances = {
    "pixiecore" = {
      module.name = "pixiecore";
      module.input = "self";
      roles.server = {
        machines."britton-fw" = { };
        settings = {
          # Enable pixiecore
          enable = true;

          # Use boot mode by default (can switch to "api" for dynamic config)
          mode = "boot";

          # Network configuration
          listenAddr = "0.0.0.0";
          port = 80;
          dhcpNoBind = false;

          # Enable debug logging
          extraOptions = [ "--debug" ];

          # SSH keys to embed in netboot image
          sshAuthorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
          ];

          # Enable kexec support
          kexecEnabled = true;

          # Additional packages for the netboot environment
          netbootPackages = with inputs.nixpkgs.legacyPackages.x86_64-linux; [
            git
            nmap
            tcpdump
            dig
            traceroute
            pciutils
            usbutils
            dmidecode
            smartmontools
            iotop
            iftop
            lsof
            strace
            parted
            gptfdisk
            nvme-cli
          ];

          # Additional netboot configuration
          netbootConfig = {
            # Serial console support
            boot.kernelParams = [
              "console=ttyS0,115200"
              "console=tty0"
            ];

            # Set a custom hostname
            networking.hostName = "nixos-installer";

            # Ensure IPv6 is enabled
            networking.enableIPv6 = true;

            # Enable mDNS for easier discovery
            services.avahi = {
              enable = true;
              publish = {
                enable = true;
                addresses = true;
                workstation = true;
              };
            };
          };
        };
      };
    };
  };
}
