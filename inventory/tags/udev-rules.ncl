# Udev device rules — structured data with validation.
#
# Consumed by udev-rules.nix which generates the rules string.
# Validates vendor/product IDs at `ncl export` time.
let HexId =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^[0-9a-fA-F]{4}$" value => 'Ok,
    _ => 'Error { message = "must be 4-digit hex ID (e.g. \"0483\")" },
  }
  )
in

let DeviceRule = {
  name | String,
  vendor | HexId | optional,
  product | HexId | optional,
  match_attr | String | optional,
  subsystem | String | optional,
}
in

{
  # Device rules — each generates a udev rule line
  devices | Array DeviceRule = [
    # STLink debug probes
    { name = "STLink V1", vendor = "0483", product = "3744" },
    { name = "STLink V2", vendor = "0483", product = "3748" },
    { name = "STLink V2-1", vendor = "0483", product = "374b" },
    { name = "STLink V2-1", vendor = "0483", product = "3752" },
    { name = "STLink V3", vendor = "0483", product = "374d" },
    { name = "STLink V3", vendor = "0483", product = "374e" },
    { name = "STLink V3", vendor = "0483", product = "374f" },
    { name = "STLink V3", vendor = "0483", product = "3753" },
    { name = "STLink V3", vendor = "0483", product = "3754" },

    # SEGGER J-Link (matches all products from this vendor)
    { name = "SEGGER J-Link", vendor = "1366" },

    # CMSIS-DAP compatible adapters (match by product string)
    { name = "CMSIS-DAP", match_attr = "*CMSIS-DAP*" },

    # Daisy Seed DFU mode
    { name = "Daisy Seed DFU", vendor = "0483", product = "df11" },

    # Qualcomm EDL/Firehose mode
    { name = "Qualcomm EDL", vendor = "05c6", product = "9008" },
    { name = "Qualcomm EDL", vendor = "05c6", product = "900e" },
    { name = "Qualcomm EDL", vendor = "05c6", product = "9091" },

    # Rockchip USB (maskrom/loader mode)
    { name = "Rockchip USB", vendor = "2207", subsystem = "usb" },
  ],

  # Groups to create for device access
  groups = ["plugdev", "dialout"],

  # Kernel modules to load at boot (modprobe names)
  kernel_modules = ["gcadapter_oc"],

  # Kernel module packages (kernelPackages attribute names)
  kernel_module_packages = ["gcadapter-oc-kmod"],

  # Nixpkgs package names providing udev rules
  udev_packages = ["dolphin-emu"],
}
