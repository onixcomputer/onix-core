# Cloud Hypervisor VM — clan service module for hosting cloud-hypervisor guests.
#
# Each instance represents one VM. The host role generates a systemd service
# that launches cloud-hypervisor with the guest's kernel, initrd, and root disk.
#
# Guest machine configs live in machines/<name>/ with the cloud-hypervisor-guest tag.
# This module runs on the HOST (e.g., britton-desktop).
{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "cloud-hypervisor-vm";
    readme = "Cloud Hypervisor VM launcher — runs NixOS guests with direct kernel boot";
  };

  roles = {
    host = {
      description = "Host that runs cloud-hypervisor VMs";
      interface = mkSettings.mkInterface schema.host;

      perInstance =
        {
          extendSettings,
          ...
        }:
        {
          nixosModule =
            {
              pkgs,
              lib,
              self,
              ...
            }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              settings = extendSettings (ms.mkDefaults schema.host);
              inherit (settings)
                guestMachine
                cpus
                memory
                diskPath
                tapInterface
                macAddress
                guestIp
                ;

              guestConfig = self.nixosConfigurations.${guestMachine}.config;
              guestSystem = guestConfig.system.build;

              # cloud-hypervisor on x86_64 requires uncompressed vmlinux (not bzImage).
              # The .dev output of the kernel package has it.
              kernel = "${guestSystem.kernel.dev}/vmlinux";
              initrd = "${guestSystem.initialRamdisk}/initrd";
              inherit (guestSystem) toplevel;
              # root=PARTLABEL matches the disko GPT partition name.
              # /dev/vda is the whole disk; /dev/vda1 is the root partition.
              kernelParams = "root=PARTLABEL=disk-main-root init=${toplevel}/init console=ttyS0,115200";

              # Multi-queue: scale with vCPU count for throughput.
              multiQueue = cpus > 1;
              diskQueues = if multiQueue then cpus else 1;
              netQueues = if multiQueue then cpus * 2 else 1;

              apiSocket = "/run/cloud-hypervisor-${guestMachine}.sock";

              chBin = "${pkgs.cloud-hypervisor}/bin/cloud-hypervisor";
            in
            {
              assertions = [
                {
                  assertion = self.nixosConfigurations ? ${guestMachine};
                  message = "cloud-hypervisor-vm: guestMachine '${guestMachine}' not found in nixosConfigurations";
                }
                {
                  assertion = builtins.match "[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}" macAddress != null;
                  message = "cloud-hypervisor-vm: macAddress '${macAddress}' is not a valid MAC address";
                }
                # Split: separate assertions for each bound so failure message
                # identifies which limit was violated.
                {
                  assertion = cpus >= 1;
                  message = "cloud-hypervisor-vm: cpus must be >= 1, got ${toString cpus}";
                }
                {
                  assertion = cpus <= 256;
                  message = "cloud-hypervisor-vm: cpus must be <= 256, got ${toString cpus}";
                }
                {
                  assertion = memory >= 128;
                  message = "cloud-hypervisor-vm: memory must be at least 128 MiB, got ${toString memory}";
                }
              ];

              systemd.services."cloud-hypervisor-${guestMachine}" = {
                description = "Cloud Hypervisor VM: ${guestMachine}";
                after = [
                  "network.target"
                  "cloud-hypervisor-network.service"
                ];
                wants = [ "cloud-hypervisor-network.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "simple";
                  TimeoutStopSec = 30;
                  Restart = "on-failure";
                  RestartSec = "10s";

                  ExecStartPre =
                    let
                      script = pkgs.writeShellApplication {
                        name = "chv-pre-${guestMachine}";
                        runtimeInputs = [ pkgs.iproute2 ];
                        text = ''
                          # Verify disk image exists.
                          if [[ ! -f "${toString diskPath}" ]]; then
                            echo "ERROR: Disk image not found: ${toString diskPath}"
                            echo "Run the bootstrap script first."
                            exit 1
                          fi

                          # Always delete+recreate the TAP. A stale TAP from a crashed run
                          # may have wrong flags (missing multi_queue or vnet_hdr), causing
                          # cloud-hypervisor's ioctl to fail when opening queue pairs.
                          # This matches microvm.nix's tap-up pattern.
                          if [ -e /sys/class/net/${tapInterface} ]; then
                            ip link delete ${tapInterface}
                          fi
                          ip tuntap add dev ${tapInterface} mode tap ${if multiQueue then "multi_queue" else ""} vnet_hdr

                          # Attach to the shared bridge. The bridge (br-chv) owns the
                          # gateway IP 172.16.0.1/24 — individual TAPs get no IP.
                          ip link set ${tapInterface} master br-chv
                          ip link set ${tapInterface} up
                        '';
                      };
                    in
                    lib.getExe script;

                  ExecStart = lib.concatStringsSep " " [
                    chBin
                    "--kernel ${kernel}"
                    "--initramfs ${initrd}"
                    "--cmdline \"${kernelParams}\""
                    "--disk path=${toString diskPath}${lib.optionalString multiQueue ",num_queues=${toString diskQueues}"}"
                    "--net tap=${tapInterface},mac=${macAddress}${lib.optionalString multiQueue ",num_queues=${toString netQueues}"}"
                    "--cpus boot=${toString cpus}"
                    "--memory size=${toString memory}M"
                    "--serial tty"
                    "--console off"
                    "--api-socket path=${apiSocket}"
                    "--seccomp true"
                    "--watchdog"
                  ];

                  ExecStop =
                    let
                      script = pkgs.writeShellApplication {
                        name = "chv-stop-${guestMachine}";
                        runtimeInputs = [ pkgs.curl ];
                        text = ''
                          # Graceful shutdown via ACPI power button.
                          curl --unix-socket ${apiSocket} -s \
                            -X PUT http://localhost/api/v1/vm.power-button || true

                          # Wait for the process to exit (bounded: 25s, leaves 5s
                          # headroom before TimeoutStopSec=30 sends SIGKILL).
                          for _i in $(seq 1 25); do
                            if ! curl --unix-socket ${apiSocket} -s \
                              http://localhost/api/v1/vm.info &>/dev/null 2>&1; then
                              exit 0
                            fi
                            sleep 1
                          done

                          # VM didn't exit within 25s — let systemd SIGKILL via TimeoutStopSec.
                          echo "WARN: VM did not shut down within 25s, systemd will SIGKILL"
                        '';
                      };
                    in
                    lib.getExe script;

                  ExecStopPost =
                    let
                      script = pkgs.writeShellApplication {
                        name = "chv-post-${guestMachine}";
                        runtimeInputs = [ pkgs.iproute2 ];
                        text = ''
                          # Clean up TAP interface.
                          if ip link show ${tapInterface} &>/dev/null; then
                            ip link delete ${tapInterface}
                          fi
                          # Clean up API socket.
                          rm -f ${apiSocket}
                        '';
                      };
                    in
                    lib.getExe script;
                };
              };

              # DHCP reservation for this guest.
              services.dnsmasq.settings = {
                dhcp-host = lib.mkAfter [
                  "${macAddress},${guestIp}"
                ];
              };

              # No per-TAP firewall or NAT entries needed — the br-chv bridge
              # is already trusted and NAT'd by the cloud-hypervisor-host tag.
            };
        };
    };
  };
}
