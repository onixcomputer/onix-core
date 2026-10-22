# Udev rules — generates rules from structured data in udev-rules.ncl.
{
  config,
  pkgs,
  wasm,
  ...
}:
let
  data = wasm.evalNickelFile ./udev-rules.ncl;

  # Generate a single udev rule line from a device record.
  mkRule =
    dev:
    if dev ? match_attr then
      ''ATTRS{product}=="${dev.match_attr}", MODE="0666", GROUP="plugdev", TAG+="uaccess"''
    else if dev ? subsystem && !(dev ? product) then
      ''SUBSYSTEM=="${dev.subsystem}", ATTR{idVendor}=="${dev.vendor}", MODE="0666", GROUP="plugdev", TAG+="uaccess"''
    else if dev ? product then
      ''ATTRS{idVendor}=="${dev.vendor}", ATTRS{idProduct}=="${dev.product}", MODE="0666", GROUP="plugdev", TAG+="uaccess"''
    else
      # Vendor-only match (e.g. SEGGER J-Link)
      ''ATTRS{idVendor}=="${dev.vendor}", MODE="0666", GROUP="plugdev", TAG+="uaccess"'';

  rulesText = builtins.concatStringsSep "\n" (
    builtins.map (dev: "# ${dev.name}\n${mkRule dev}") data.devices
  );

  # nixpkgs' kernel-module aggregator expects a kmodigest certificate
  # (`<module>.ko.cer`) beside every external module. gcadapter-oc-kmod installs
  # its module by hand and skips Kbuild's signing step, so certify it after the
  # fixup phase has stripped it.
  withModuleCertificates =
    package:
    package.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.buildPackages.kmodigest ];
      postFixup = (old.postFixup or "") + ''
        find "$out/lib/modules" -name '*.ko' -print0 | while IFS= read -r -d "" module; do
          test -e "$module.cer" || kmodigest "$module"
        done
      '';
    });
in
{
  # Udev packages from nixpkgs (e.g. dolphin-emu controller rules)
  services.udev.packages = builtins.map (name: pkgs.${name}) data.udev_packages;

  # GameCube adapter overclock kernel module
  boot.extraModulePackages = builtins.map (
    name: withModuleCertificates config.boot.kernelPackages.${name}
  ) data.kernel_module_packages;

  boot.kernelModules = data.kernel_modules;

  services.udev.extraRules = rulesText;

  # Ensure groups exist
  users.groups = builtins.listToAttrs (
    builtins.map (g: {
      name = g;
      value = { };
    }) data.groups
  );
}
