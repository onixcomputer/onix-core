# PineNote Technical Reference

PINE64 PineNote E-Ink Tablet — Hardware and Software Documentation
Source: <https://pine64.org/documentation/PineNote/_full/>

## Hardware

### Display — E-Ink ED103TC2
- **Panel**: E-Ink ED103TC2, 10.3", 1404×1872, 227 DPI, 16-level grayscale
- **Frontlight**: LM3630A, 36 levels, cold/warm adjustable
- **Capacitive touch**: Cypress CYTTSP5 (mainline 6.2+)
- **Digitizer**: Wacom SUDE-10S15MI-01X via i2c_hid_of (mainline)

### SoC — Rockchip RK3566
- **CPU**: Quad-core ARM Cortex-A55 @ 1.8 GHz
- **GPU**: Mali-G52 2EE Bifrost @ 800 MHz
- **NPU**: 0.8 TOPS
- **Process**: 22nm FD-SOI
- **Cache**: 512KB L3, 32KB L1i+L1d per core

### Memory / Storage
- 4GB LPDDR4
- 128GB eMMC (Biwin BWCTASC41P128G), `/dev/mmcblk0`

### Connectivity
- **WiFi**: 802.11a/b/g/n/ac dual-band, Azurewave CM256SM (Broadcom BCM4345C0), `brcmfmac`
- **Bluetooth**: 5.0 LE, `brcmfmac`
- **USB**: USB-C, USB 2.0 (480 Mbps), 5V/3A charging, no DisplayPort

### Audio
- Stereo speakers, 4× DMIC, Awinic AW87318 Class-K amp, RK817 codec

### Sensors
- **Accelerometer**: Silan SC7A20, `st-accel-i2c` (mainline 5.18+)
- **Hall sensor**: U9009 (back, top-right), used for Maskrom mode entry

### Power
- 4000 mAh LiPo, RK817 main PMIC, TI TPS65185 e-ink PMIC

### Physical
- 191.1 × 232.5 × 7.4 mm, 438g

## Linux Driver Status

### Mainlined
- touchscreen: cyttsp5 (6.2+)
- digitizer: i2c_hid_of
- wifi/bluetooth: brcmfmac
- accelerometer: st-accel-i2c (5.18+)
- backlight: lm3630a
- gpu: panfrost (disabled upstream pending EBC)

### Custom Kernel Required
- **E-ink display**: `rockchip-ebc` — RFC/WIP, NOT mainlined. Kernel: `github.com/m-weigand/linux branch_pinenote_6-6-30`. Alt: `github.com/hrdl/linux` (per-pixel scheduling).
- **E-ink PMIC**: `tps65185` — in development.
- **Suspend/resume**: `rockchip-sip` — requires downstream TF-A, NOT mainlinable.
- **RGA graphics**: `rga` (v4l2) — WIP hardware dithering/Y4.

## E-Ink Display

### Refresh Modes
| Mode   | Description                     |
|--------|---------------------------------|
| A1     | Fast B&W (<100ms), limited gray |
| A2     | Balanced speed/quality          |
| GC16   | Highest quality (>500ms)        |
| GL16   | Reduced ghosting                |
| GLR16  | Full waveform refresh           |

### Waveform Data
Device-unique, stored in dedicated 2MB partition. **MUST backup before any repartitioning.**

## Boot

### UART
1500000 baud, 8N1, no flow control. SBU1 (A8) = UART2_TX, SBU2 (B8) = UART2_RX. Requires 1K ohm pull-ups to 3.3V.

### Maskrom Entry
- Magnet on hall sensor U9009 (top-right quadrant, back)
- U-Boot: `rockusb 0 mmc 0` via UART
- Test point: short TP1301 (GND) + TP1302 (eMMC_D0)

### October 2024 Batch U-Boot Fix
Factory U-Boot had suspend/resume bugs. Fix: `cd /root/uboot && bash install_stable_1056mhz_uboot.sh`

## Partition Layout

| # | Name       | Size      | Purpose                                     |
|---|------------|-----------|---------------------------------------------|
| 1 | uboot      | 64 MB     | Bootloader (preserved)                      |
| 2 | waveform   | 2 MB      | E-ink calibration (CRITICAL — preserved)    |
| 3 | uboot_env  | 1 MB      | U-Boot environment (preserved)              |
| 4 | logo       | 64 MB     | Boot splash (preserved)                     |
| 5 | os1        | 15 GB     | Debian/recovery (ext4, label=os1)           |
| 6 | os2        | 15 GB     | NixOS (ext4, label=nixos) ← bootmenu_2     |
| 7 | data       | remaining | Shared user data (ext4, label=data)         |

U-Boot bootmenu: option 1 = part 5, option 2 = part 6. NixOS boots from partition 6.

## Clan Commands

```bash
# Build
build pine
nix build .#nixosConfigurations.pine.config.system.build.toplevel

# Flash (direct to eMMC)
clan flash write pine --disk main /dev/mmcblk0 --ssh-pubkey ~/.ssh/id_ed25519.pub --mode format

# Network install
clan machines install pine --target-host root@<IP> --update-hardware-config nixos-facter --phases kexec,disko,install,reboot

# Update running system (cross-compiled on britton-desktop)
clan machines update pine

# Backup waveform BEFORE repartitioning
dd if=/dev/mmcblk0p2 of=waveform_backup.bin bs=1M

# Post-install
sudo setup-waveform.sh
```

## Firmware
- WiFi/BT: LibreELEC firmware versions recommended — `brcmfmac43455-sdio.pine64,pinenote-v1.2.{txt,bin}`
- Waveform: device-unique, backup mandatory

## Known Issues
- **Suspend broken** (Oct 2024 batch): flash stable U-Boot from `/root/uboot/`
- **Touchscreen inverted**: `rockchip_ebc.panel_reflection=0` kernel parameter
- **Bluetooth audio stutter**: modified device tree + `max-speed=3000000`
- **Charging LED bleed**: software LED disable when screen active

## Input Configuration

Sway pen input: `input "type:table_tool" calibration_matrix -1 0 1 0 -1 1`

## Links
- [Pine64 docs](https://pine64.org/documentation/PineNote/_full/)
- [Pine64 development wiki](https://wiki.pine64.org/wiki/PineNote_Development)
- [m-weigand kernel](https://github.com/m-weigand/linux) (branch_pinenote_6-6-30)
- [pinenote-nixos](https://github.com/WeraPea/pinenote-nixos) — primary NixOS module
- [NixOS on ARM](https://wiki.nixos.org/wiki/NixOS_on_ARM)
