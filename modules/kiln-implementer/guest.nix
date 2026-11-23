# r[impl onix.kiln_implementation.guest]
# Explicit separate profile; never imported by static guests or no-network CI.
{
  nixpkgs,
  system ? "x86_64-linux",
  cohort,
  vmm,
  cpus ? 2,
  memoryMiB ? 2048,
  memoryBacking ? "private",
  mergeable ? false,
}:
let
  inherit (nixpkgs) lib;
  pkgs = import nixpkgs { inherit system; };
  guest = lib.nixosSystem {
    inherit system;
    modules = [
      ({ pkgs, ... }: {
        system.stateVersion = "26.05";
        networking.hostName = "lattice-worker";
        networking.useDHCP = false;
        boot = {
          loader.grub.enable = false;
          kernelParams = [
            "console=ttyS0,115200"
            "panic=1"
          ];
          initrd = {
            systemd.enable = false;
            availableKernelModules = [
              "virtio_pci"
              "virtio_blk"
              "virtio_rng"
              "vmw_vsock_virtio_transport"
              "squashfs"
              "overlay"
              "ext4"
            ];
            postMountCommands = lib.mkBefore ''
              mkdir -p /mnt-root/state/nix-store/upper /mnt-root/state/nix-store/work /mnt-root/state/nix-var /mnt-root/nix/store /mnt-root/nix/var
              mount -t overlay -o lowerdir=/mnt-root/nix/.ro-store,upperdir=/mnt-root/state/nix-store/upper,workdir=/mnt-root/state/nix-store/work overlay /mnt-root/nix/store
              mount --bind /mnt-root/state/nix-var /mnt-root/nix/var
            '';
          };
          supportedFilesystems = [
            "squashfs"
            "overlay"
            "ext4"
          ];
          readOnlyNixStore = false;
        };
        # vda is immutable; vdb and vdc are independently owned per attempt.
        fileSystems = {
          "/" = {
            device = "tmpfs";
            fsType = "tmpfs";
            options = [ "mode=0755" ];
          };
          "/nix/.ro-store" = {
            device = "/dev/vda";
            fsType = "squashfs";
            options = [ "ro" ];
            neededForBoot = true;
          };
          "/workspace" = {
            device = "/dev/vdb";
            fsType = "ext4";
            options = [
              "nosuid"
              "nodev"
            ];
            neededForBoot = true;
          };
          "/state" = {
            device = "/dev/vdc";
            fsType = "ext4";
            options = [
              "nosuid"
              "nodev"
            ];
            neededForBoot = true;
          };
        };
        environment = {
          systemPackages = [
            cohort.environment
            pkgs.util-linux
          ];
          etc."lattice/workflow.ncl".source = cohort.workflow;
          etc."machine-id".source = "/state/machine-id";
        };
        system.activationScripts.workerState = lib.stringAfter [ "users" ] ''
          if ! test -s /state/machine-id; then
            ${pkgs.util-linux}/bin/uuidgen | ${pkgs.coreutils}/bin/tr -d '-' > /state/machine-id
            chmod 0444 /state/machine-id
          fi
          mkdir -p /state/lattice /nix/var/nix/gcroots
          chown lattice:lattice /state/lattice /workspace
          ${pkgs.nix}/bin/nix-store --load-db < /nix/.ro-store/registration
          ln -sfn /run/current-system /nix/var/nix/gcroots/worker-environment
        '';
        nix.gc.automatic = false;
        nix.settings = {
          auto-optimise-store = false;
          sandbox = true;
        };
        users.users.lattice = {
          isSystemUser = true;
          group = "lattice";
          home = "/state/lattice";
        };
        users.groups.lattice = { };
        services.openssh.enable = false;
        # No reusable key or publisher credential, no model network, no auto-run.
        # The existing host/session owner must supply its qualified guest channel.
        systemd.services.lattice-worker-exchange = {
          description = "Pinned Lattice production executor; operator/channel admitted";
          serviceConfig = {
            User = "lattice";
            Group = "lattice";
            UMask = "0077";
            WorkingDirectory = "/workspace";
            ExecStart = "${cohort.lattice}/bin/lattice --config /state/lattice/config.ncl workflow-exchange serve --profile /state/lattice/handler-profile.ncl";
            ReadWritePaths = [
              "/workspace"
              "/state/lattice"
            ];
            ProtectSystem = "strict";
            ProtectHome = true;
            NoNewPrivileges = true;
            PrivateTmp = true;
            KillMode = "control-group";
            Restart = "no";
          };
        };
      })
    ];
  };
  closure = pkgs.closureInfo {
    rootPaths = [
      guest.config.system.build.toplevel
      cohort
    ];
  };
  storeImage =
    pkgs.runCommand "lattice-worker-immutable-store.raw"
      {
        nativeBuildInputs = [
          pkgs.squashfsTools
          pkgs.coreutils
        ];
      }
      ''
        mkdir store
        while IFS= read -r path; do
          cp -a --reflink=auto "$path" "store/$(basename "$path")"
        done < ${closure}/store-paths
        cp ${closure}/registration store/registration
        mksquashfs store "$out" -noappend -all-root -no-xattrs -processors 1
      '';
  launch = pkgs.writeText "lattice-worker-launch.json" (
    builtins.toJSON {
      schema = "onix.lattice.worker-launch.v1";
      architecture = system;
      kernel = "${guest.config.system.build.kernel.dev}/vmlinux";
      initrd = "${guest.config.system.build.initialRamdisk}/initrd";
      root = toString storeImage;
      cmdline = "init=${guest.config.system.build.toplevel}/init console=ttyS0,115200 panic=1";
      inherit
        cpus
        memoryMiB
        memoryBacking
        mergeable
        ;
      memory_source = "anonymous";
      hugepages = false;
      cpu_model = "host";
      max_vcpus = cpus;
      disk_image_type = "raw";
      workspace_device = "/dev/vdb";
      state_device = "/dev/vdc";
      network = "none";
      migration_mode = "precopy";
      postcopy = false;
      memfds = false;
      session_gateway = "unqualified:existing-per-job-gateway-is-not-retained";
    }
  );
in
assert lib.assertMsg (
  system == "x86_64-linux"
) "Worker guest currently packages x86_64-linux only; other platforms unsupported";
assert lib.assertMsg (
  cpus >= 1 && cpus <= 8 && memoryMiB >= 512 && memoryMiB <= 16384
) "Worker guest resource bounds exceeded";
assert lib.assertMsg (memoryBacking == "private" && !mergeable)
  "Selected retained host baseline supports only anonymous private non-mergeable memory; shared backing is a separate unqualified profile";
pkgs.runCommand "lattice-worker-guest"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.b3sum
    ];
    passthru = {
      inherit
        guest
        storeImage
        launch
        closure
        cohort
        vmm
        ;
    };
  }
  ''
    mkdir -p "$out"
    ln -s ${storeImage} "$out/root.raw"
    ln -s ${guest.config.system.build.kernel.dev}/vmlinux "$out/vmlinux"
    ln -s ${guest.config.system.build.initialRamdisk}/initrd "$out/initrd"
    ln -s ${guest.config.system.build.toplevel} "$out/system"
    ln -s ${cohort} "$out/cohort"
    ln -s ${launch} "$out/launch.json"
    ln -s ${vmm}/bin/cloud-hypervisor "$out/cloud-hypervisor"
    python3 - "$out" <<'PY'
    import json, pathlib, re, subprocess, sys
    root = pathlib.Path(sys.argv[1])
    def digest(path):
        return subprocess.check_output(["b3sum", "--no-names", str(path)], text=True).strip()
    entries = {}
    for name in ["vmlinux", "initrd", "root.raw", "launch.json", "cloud-hypervisor"]:
        path = (root / name).resolve(strict=True)
        entries[name] = {"path": str(path), "blake3": digest(path)}
    binary = pathlib.Path(entries["cloud-hypervisor"]["path"])
    with binary.open("rb") as stream:
        header = stream.read(20)
    if header[:6] != b"\x7fELF\x02\x01" or header[18:20] != b"\x3e\x00":
        raise SystemExit("selected CH must be the actual x86_64 ELF, not a delegating wrapper")
    actual = subprocess.check_output([entries["cloud-hypervisor"]["path"], "--version"], text=True, timeout=10).strip()
    if not re.fullmatch(r"cloud-hypervisor v54\.0(?:\.\d+)?(?:[-+ ].*)?", actual):
        raise SystemExit("unsupported actual CH version for this selected retained host profile")
    manifest = {"schema": "onix.lattice.worker-guest.v1", "architecture": "${system}",
        "kernel_version": "${guest.config.system.build.kernel.version}",
        "entries": entries, "vmm_actual_version": actual,
        "cohort_manifest": str(root / "cohort" / "manifest.json"),
        "cohort_blake3": digest(root / "cohort" / "manifest.json"),
        "launch": json.loads((root / "launch.json").read_text()),
        "qualification": {p: "unqualified" for p in ["boot", "restore", "migration", "memory-backing", "lattice-guest", "host-channel"]}}
    (root / "manifest.json").write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")
    PY
  ''
