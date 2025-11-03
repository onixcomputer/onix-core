{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Embedded development tools for Daisy and other ARM Cortex-M devices
    probe-rs-tools
    cargo-binutils
    flip-link
    libusb1

    # USB debugging and flashing tools
    usbutils # provides lsusb
    dfu-util # for DFU mode flashing

    # Serial communication tools
    screen # for serial terminal
    minicom # alternative serial terminal
    picocom # lightweight serial terminal

    # Additional debug probe support
    openocd # open on-chip debugger

    # Logic analyzer and protocol analysis
    sigrok-cli # command line logic analyzer
    pulseview # GUI logic analyzer and oscilloscope

    # Oscilloscope software
    openhantek6022 # USB oscilloscope software

    # PCB design tools
    kicad # electronic design automation suite
  ];
}
