# Intel E810 RoCE v2 direct-link setup for hosts that carry an E810 network card.
#
# This tag needs an RDMA-capable controller and fails closed for a host whose
# hardware inventory lists none. The Strix Halo unified-memory tuning that used
# to live here belongs to the gpu-unified-memory tag.
# Reference: https://github.com/kyuz0/amd-strix-halo-vllm-toolboxes/blob/main/rdma_cluster/setup_guide.md
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  rdmaHardware = import ../../lib/rdma-hardware.nix { inherit lib; };

  rdmaGroup = "rdma";
  rdmaInterface = "rdma0";
  intelE810Driver = "ice";
  intelE810RdmaDriver = "irdma";
  roceSubnetCidr = "192.168.100.0/30";
  jumboMtuBytes = 9000;
  rdmaDeviceMode = "0660";
  unlimitedMemlock = "unlimited";

  rdmaAddresses = {
    aspen1 = "192.168.100.1/30";
    aspen2 = "192.168.100.2/30";
  };

  hostname = config.networking.hostName;
  rdmaAddress = rdmaAddresses.${hostname} or null;
  hasRdmaController = rdmaHardware.hasRdmaController { inherit self hostname; };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = rdmaAddress != null;
          message = ''
            The rdma-cluster tag requires a static RDMA address mapping for ${hostname}.
            Add ${hostname} to rdmaAddresses in inventory/tags/rdma-cluster.nix before assigning the tag.
          '';
        }
        {
          assertion = hasRdmaController;
          message = ''
            The rdma-cluster tag requires an RDMA-capable network controller, and the
            hardware inventory in machines/${hostname}/facter.json lists none.
            Remove the tag for this host, or add the controller before assigning the tag.
          '';
        }
      ];
    }

    (lib.mkIf (rdmaAddress != null) {
      boot = {
        kernelModules = [
          intelE810Driver
          intelE810RdmaDriver
          "ib_uverbs"
          "rdma_cm"
          "rdma_ucm"
        ];
        kernelParams = [
          # RoCE performance and link stability for the add-in E810 card.
          "iommu=pt"
          "pci=realloc"
          "pcie_aspm=off"
        ];
      };

      environment.systemPackages = with pkgs; [
        ethtool
        iproute2
        pciutils
        qperf
        rdma-core
      ];

      networking = {
        firewall.trustedInterfaces = [ rdmaInterface ];
        networkmanager.unmanaged = [
          "driver:${intelE810Driver}"
          "interface-name:${rdmaInterface}"
        ];
      };

      security.pam.loginLimits = [
        {
          domain = "@${rdmaGroup}";
          item = "memlock";
          type = "-";
          value = unlimitedMemlock;
        }
      ];

      services.udev = {
        # Keep RDMA device permissions explicit instead of importing rdma-core's
        # upstream udev rules, which include an SRP rule with /bin/systemctl.
        extraRules = ''
          SUBSYSTEM=="infiniband", GROUP="${rdmaGroup}", MODE="${rdmaDeviceMode}"
          SUBSYSTEM=="infiniband_mad", GROUP="${rdmaGroup}", MODE="${rdmaDeviceMode}"
          SUBSYSTEM=="infiniband_verbs", GROUP="${rdmaGroup}", MODE="${rdmaDeviceMode}"
          KERNEL=="rdma_cm", GROUP="${rdmaGroup}", MODE="${rdmaDeviceMode}"
          KERNEL=="uverbs*", GROUP="${rdmaGroup}", MODE="${rdmaDeviceMode}"
          KERNEL=="umad*", GROUP="${rdmaGroup}", MODE="${rdmaDeviceMode}"
        '';
      };

      systemd = {
        network = {
          enable = true;
          links."10-rdma-e810" = {
            matchConfig.Driver = intelE810Driver;
            linkConfig = {
              Name = rdmaInterface;
              MTUBytes = toString jumboMtuBytes;
            };
          };
          networks."50-rdma-cluster" = {
            matchConfig.Name = rdmaInterface;
            address = [ rdmaAddress ];
            routes = [
              {
                Destination = roceSubnetCidr;
                Scope = "link";
              }
            ];
            networkConfig = {
              DHCP = "no";
              LinkLocalAddressing = "no";
            };
            linkConfig.MTUBytes = toString jumboMtuBytes;
          };
        };
        services.systemd-networkd.stopIfChanged = false;
      };

      users = {
        groups.${rdmaGroup} = { };
        users.brittonr.extraGroups = [ rdmaGroup ];
      };
    })
  ];
}
