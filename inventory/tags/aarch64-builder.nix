_: {
  # Configure m2 as a remote aarch64 builder
  # This tag should be applied to machines that need to build aarch64 packages
  # x86_64 builds happen locally, aarch64 builds automatically use the remote builder
  # since we've disabled aarch64 QEMU emulation in cross-compile.nix
  nix = {
    distributedBuilds = true;
    settings = {
      builders = "@/etc/nix/machines";
      builders-use-substitutes = true;
      trusted-users = [ "brittonr" ];
      # Set to 1 to allow some local builds but prefer remote for unsupported systems
      max-jobs = 1;
      # NOTE: We set max-jobs low to encourage offloading to m2 for aarch64
      # x86_64 builds can still happen locally, but aarch64 will use m2
    };
    buildMachines = [
      {
        protocol = "ssh-ng";
        hostName = "m2.bison-tailor.ts.net";
        systems = [ "aarch64-linux" ];
        maxJobs = 6;
        speedFactor = 2;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
        ];
        mandatoryFeatures = [ ];
        sshUser = "root";
        sshKey = "/root/.ssh/id_m2";
      }
    ];
  };

  # Copy framework SSH key to /root/.ssh/id_m2 for builder access
  system.activationScripts.m2-builder-key = ''
    mkdir -p /root/.ssh
    if [ -f /home/brittonr/.ssh/framework ]; then
      cp /home/brittonr/.ssh/framework /root/.ssh/id_m2
      chmod 600 /root/.ssh/id_m2
    fi
  '';

  # Add m2 to known hosts for SSH
  programs.ssh.knownHosts.m2 = {
    hostNames = [
      "m2"
      "m2.bison-tailor.ts.net"
    ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ05g4bAY8EsmySlCMxAEyTRjs/g/SpggreGoe9XTsXz";
  };
}
