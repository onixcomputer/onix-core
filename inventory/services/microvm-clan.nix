_: {
  instances = {
    # Test VM using clan machine configuration
    clan-test-vm = {
      module.name = "microvm-clan";
      module.input = "self";
      roles.server = {
        machines."britton-desktop" = {
          settings = {
            clanMachine = "test-vm";
            restartIfChanged = false;
            microvm = {
              vcpu = 2;
              mem = 1024;
              vsock.cid = 5;
              hypervisor = "cloud-hypervisor";
            };
          };
        };
      };
    };

    # Monitoring VM using clan machine configuration
    clan-monitoring-vm = {
      module.name = "microvm-clan";
      module.input = "self";
      roles.server = {
        machines."britton-desktop" = {
          settings = {
            clanMachine = "monitoring-vm";
            restartIfChanged = true;
            microvm = {
              vcpu = 4;
              mem = 2048;
              vsock.cid = 6;
              hypervisor = "cloud-hypervisor";
            };
          };
        };
      };
    };
  };
}
