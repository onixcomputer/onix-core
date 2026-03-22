# Machine inventory — source of truth.
#
# Defines every machine, its tags, and deployment targets.
# Validated by Nickel contracts at export time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/core/machines.ncl
#   3. Contracts are checked during export — typos and missing fields fail immediately
#   4. Commit .ncl
#
let { Machines, .. } = import "contracts.ncl" in

{
  machines = {
    # ========== Laptops ==========

    britton-fw = {
      name = "britton-fw",
      system = "x86_64-linux",
      tags = [
        "hm-laptop",
        "ssd-optimization",
        "perf-tuning",
        "printing",
        "dev",
        "laptop",
        "laptop-input",
        "greeter",
        "audio",
        "grub-theme",
        "remote-builders",
        "xdg-portal",
        "prometheus",
        "monitoring",
        "homepage-server",
        "static-test",
        "static-demo",
        "traefik-blr",
        "tailnet-brittonr",
        "openpgp",
        "password-manager",
        "typst",
        "llm-client",
        "cross-compile",
        "creative",
        "docker",
        "taskwarrior",
        "backup",
        "syncthing",
      ],
      deploy.targetHost = "root@iroh-britton-fw",
    },

    bonsai = {
      name = "bonsai",
      system = "x86_64-linux",
      tags = [
        "hm-laptop",
        "ssd-optimization",
        "perf-tuning",
        "printing",
        "dev",
        "laptop",
        "laptop-input",
        "greeter",
        "audio",
        "grub-theme",
        "remote-builders",
        "xdg-portal",
        "prometheus",
        "monitoring",
        "homepage-server",
        "tailnet-brittonr",
        "openpgp",
        "password-manager",
        "typst",
        "llm-client",
        "cross-compile",
        "creative",
        "taskwarrior",
        "udev-rules",
        "gaming",
        "backup",
        "syncthing",
      ],
      deploy.targetHost = "root@iroh-bonsai",
    },

    # ========== Servers ==========

    aspen1 = {
      name = "aspen1",
      system = "x86_64-linux",
      tags = [
        "hm-server",
        "minimal-docs",
        "ssd-optimization",
        "docker",
        "tailnet-brittonr",
        "dev",
        "prometheus",
        "monitoring",
        "homepage-server",
        "amd-gpu",
        "initrd-ssh",
        "remote-builders",
        "thunderbolt-link",
        "llamacpp-server",
      ],
      deploy.targetHost = "root@iroh-aspen1",
    },

    aspen2 = {
      name = "aspen2",
      system = "x86_64-linux",
      tags = [
        "hm-server",
        "minimal-docs",
        "ssd-optimization",
        "docker",
        "tailnet-brittonr",
        "dev",
        "prometheus",
        "monitoring",
        "homepage-server",
        "amd-gpu",
        "initrd-ssh",
        "remote-builders",
        "backup",
        "thunderbolt-link",
        "llamacpp-worker",
      ],
      deploy.targetHost = "root@iroh-aspen2",
    },

    # ========== Desktop ==========

    britton-desktop = {
      name = "britton-desktop",
      system = "x86_64-linux",
      addresses.lan = "britton-desktop",
      tags = [
        "ssd-optimization",
        "perf-tuning",
        "printing",
        "dev",
        "desktop",
        "laptop-input",
        "greeter",
        "audio",
        "xdg-portal",
        "nvidia",
        "creative",
        "media",
        "prometheus",
        "monitoring",
        "homepage-server",
        "traefik-desktop",
        "static-test",
        "static-demo",
        "docker",
        "llm-client",
        "llm",
        "password-manager",
        "cross-compile",
        "udev-rules",
        "cloud-hypervisor-host",
        "taskwarrior",
        "initrd-ssh",
        "backup",
        "syncthing",
      ],
      deploy.targetHost = "root@britton-desktop",
    },

    # ========== SBCs ==========

    pine = {
      name = "pine",
      system = "aarch64-linux",
      tags = [
        "hm-server",
        "minimal-docs",
        "pinenote",
        "tailnet-brittonr",
        "dev",
      ],
      deploy.targetHost = "root@iroh-pine",
      deploy.buildHost = "britton-desktop",
    },

    # ========== VMs ==========

    utm-vm = {
      name = "utm-vm",
      system = "aarch64-linux",
      tags = [
        "minimal-docs",
        "ssd-optimization",
      ],
      deploy.targetHost = "root@iroh-utm-vm",
    },

    # ========== Cloud Hypervisor VMs ==========

    chv-dev1 = {
      name = "chv-dev1",
      system = "x86_64-linux",
      tags = [
        "cloud-hypervisor-guest",
        "minimal-docs",
      ],
      deploy = {
        targetHost = "root@172.16.0.10",
        buildHost = "britton-desktop",
      },
    },

    chv-dev2 = {
      name = "chv-dev2",
      system = "x86_64-linux",
      tags = [
        "cloud-hypervisor-guest",
        "minimal-docs",
      ],
      deploy = {
        targetHost = "root@172.16.0.11",
        buildHost = "britton-desktop",
      },
    },

    chv-dev3 = {
      name = "chv-dev3",
      system = "x86_64-linux",
      tags = [
        "cloud-hypervisor-guest",
        "minimal-docs",
      ],
      deploy = {
        targetHost = "root@172.16.0.12",
        buildHost = "britton-desktop",
      },
    },

    # ========== macOS ==========

    britton-air = {
      name = "britton-air",
      system = "aarch64-darwin",
      machineClass = "darwin",
      addresses.lan = "britton-air.local",
      tags = [],
      deploy.targetHost = "root@britton-air.local",
    },
  },
} | Machines
