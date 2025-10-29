{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Embedded development tools for Daisy and other ARM Cortex-M devices
    probe-rs
    cargo-binutils
    flip-link
    libusb1

    # USB debugging and flashing tools
    usbutils # provides lsusb
    dfu-util # for DFU mode flashing
  ];
}
