# Machine inventory — source of truth.
#
# Defines every machine, its tags, and deployment targets.
# Validated by Nickel contracts at export time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/core/machines.ncl > inventory/core/machines.json
#   3. Contracts are checked during export — typos and missing fields fail immediately
#   4. Commit both .ncl and .json
#
let { Machines, .. } = import "contracts.ncl" in

{
  machines = {
    # ========== Britton Machines ===========
    britton-fw = {
      name = "britton-fw",
      tags = [
        "hm-laptop",
        "ssd-optimization",
        "perf-tuning",
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
      ],
      deploy = {
        targetHost = "root@iroh-britton-fw",
        buildHost = "",
      },
    },

    bonsai = {
      name = "bonsai",
      tags = [
        "hm-laptop",
        "ssd-optimization",
        "perf-tuning",
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
      ],
      deploy = {
        targetHost = "root@iroh-bonsai",
        buildHost = "",
      },
    },

    aspen1 = {
      name = "aspen1",
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
      ],
      deploy = {
        targetHost = "root@iroh-aspen1",
        buildHost = "",
      },
    },

    aspen2 = {
      name = "aspen2",
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
      ],
      deploy = {
        targetHost = "root@iroh-aspen2",
        buildHost = "",
      },
    },

    britton-desktop = {
      name = "britton-desktop",
      tags = [
        "ssd-optimization",
        "perf-tuning",
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
        "remote-builders",
        "cross-compile",
        "udev-rules",
        "cloud-hypervisor-host",
        "taskwarrior",
        "initrd-ssh",
        "backup",
      ],
      deploy = {
        targetHost = "root@britton-desktop",
        buildHost = "",
      },
    },

    pine = {
      name = "pine",
      tags = [
        "hm-server",
        "minimal-docs",
        "pinenote",
        "tailnet-brittonr",
        "dev",
      ],
      deploy = {
        targetHost = "root@iroh-pine",
        buildHost = "britton-desktop",
      },
    },

    # ========== VMs ===========
    utm-vm = {
      name = "utm-vm",
      tags = [
        "minimal-docs",
        "ssd-optimization",
      ],
      deploy = {
        targetHost = "root@iroh-utm-vm",
        buildHost = "",
      },
    },

    # ========== macOS Machines ===========
    britton-air = {
      name = "britton-air",
      machineClass = "darwin",
      tags = [],
      deploy = {
        targetHost = "root@britton-air.local",
        buildHost = "",
      },
    },
  },
} | Machines
