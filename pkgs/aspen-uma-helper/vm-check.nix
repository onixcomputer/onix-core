{
  pkgs,
  probe,
  source,
}:
let
  imageMiB = 64;
  fatBits = 32;
  memoryMiB = 512;
  timeoutSeconds = 60;
in
pkgs.runCommand "aspen-uma-uefi-smoke"
  {
    nativeBuildInputs = [
      pkgs.grub2_efi
      pkgs.dosfstools
      pkgs.mtools
      pkgs.qemu
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    mkdir -p "$out"
    grub-mkstandalone -O x86_64-efi -o loader.efi --modules="normal chain search fat part_gpt part_msdos serial halt" \
      "boot/grub/grub.cfg=${source}/tests/uefi/grub.cfg"
    for case_name in valid malformed stale; do
      mkdir "$case_name"
      cd "$case_name"
      truncate -s ${toString imageMiB}M esp.img
      mkfs.fat -F${toString fatBits} esp.img
      mmd -i esp.img ::/EFI ::/EFI/BOOT ::/EFI/OnixUMA
      mcopy -i esp.img ../loader.efi ::/EFI/BOOT/BOOTX64.EFI
      if [ "$case_name" = malformed ]; then
        printf 'not a PE image\n' > probe.efi
      else
        cp ${probe}/bin/uma-probe.efi probe.efi
      fi
      mcopy -i esp.img probe.efi ::/EFI/OnixUMA/probe.efi
      if [ "$case_name" = stale ]; then
        printf 'previous probe result must remain unchanged\n' > old.log
        mcopy -i esp.img old.log ::/EFI/OnixUMA/probe.log
      fi
      cp ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd vars.fd
      chmod u+w vars.fd
      timeout ${toString timeoutSeconds} qemu-system-x86_64 \
        -machine q35 -accel tcg -m ${toString memoryMiB} \
        -drive if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.fd}/FV/OVMF_CODE.fd \
        -drive if=pflash,format=raw,file=vars.fd \
        -drive if=virtio,format=raw,file=esp.img \
        -display none -serial file:serial.log -monitor none -nic none -no-reboot
      grep -F UMA_VM_RETURNED serial.log
      if [ "$case_name" = valid ]; then
        mcopy -i esp.img ::/EFI/OnixUMA/probe.log probe.log
        grep -Fx 'firmware_updates=disabled' probe.log
        grep -Fx 'apcb.locate=0x800000000000000e' probe.log
        grep -Fx 'completed=true' probe.log
      elif [ "$case_name" = malformed ]; then
        if mcopy -i esp.img ::/EFI/OnixUMA/probe.log probe.log; then
          echo 'Malformed image unexpectedly produced a report' >&2
          exit 1
        fi
      else
        mcopy -i esp.img ::/EFI/OnixUMA/probe.log probe.log
        cmp old.log probe.log
      fi
      cp serial.log "$out/$case_name-serial.log"
      if [ -f probe.log ]; then cp probe.log "$out/$case_name-probe.log"; fi
      cd ..
    done
  ''
