#!/bin/bash

echo -e "Setup the Image file...\n\n"

# Image creation
iName=`echo ${UNIT} | tr '[:lower:]' '[:upper:]'`
DISK="dArkMoss_${iName}_${DEBIAN_CODE_NAME}_${BUILD_DATE}.img"
dd if=/dev/zero of="${DISK}" bs=1M count=0 seek="${DISK_SIZE}" conv=fsync
parted -s "${DISK}" mklabel msdos
parted -s "${DISK}" -a min unit s mkpart primary fat32 ${SYSTEM_PART_START} ${SYSTEM_PART_END}
parted -s "${DISK}" set 1 boot on
parted -s "${DISK}" -a min unit s mkpart primary ${ROOT_FILESYSTEM_FORMAT} ${STORAGE_PART_START} ${STORAGE_PART_END}
#parted -s "${DISK}" set 2 lba off
sync



# Build uboot and install it to the image
if [ "$UNIT" == "rg351mp" ] || [ "$UNIT" == "g350" ] || [ "$UNIT" == "a10mini" ] || [ "$UNIT" == "xumini" ]; then
  git clone --depth=1 https://github.com/christianhaitian/RG351MP-u-boot u-boot-${CHIPSET}
else
  git clone --depth=1 https://github.com/christianhaitian/u-boot-${CHIPSET}
fi
cd u-boot-${CHIPSET}
if [ "$UNIT" == "xumini" ]; then
  # xumini-uboot.dts is ours; RG351MP-u-boot has no such unit upstream.
  patch -p1 < ../patches/xumini/uboot/0001-arch-arm-dts-Makefile.patch
  # hwrev learns the Mini M's ADC band, so it asks for xumini-uboot.dtb by name.
  patch -p1 < ../patches/xumini/uboot/0002-hwrev-xumini.patch
  cp ../patches/xumini/uboot/xumini-uboot.dts arch/arm/dts/
fi
./make.sh odroidgoa
if [ "$UNIT" == "g350" ]; then
  # Our G350 stays dark on DDR v1.10 + miniloader v1.12: pack UnofficialOS's
  # pair (RetroGFX/rkbin 5257e54) instead, checksum-pinned.
  G350_RKBIN="https://raw.githubusercontent.com/RetroGFX/rkbin/5257e54cc6c15fef28c3b73bd95ca1b55cc8c8cd/bin/rk33"
  wget -t 5 -T 30 -q "${G350_RKBIN}/rk3326_ddr_333MHz_v1.15.bin" "${G350_RKBIN}/rk3326_miniloader_v1.28.bin" &&
  printf '%s\n' "e9cf34058bb39478d22d3a3dc325a8e8ca079fb1edb145e0f4db76acfaea4d8b  rk3326_ddr_333MHz_v1.15.bin" \
    "dc7f78343f0e02492915802e82d6daf36d097172671dfd26f14612e91c52dd42  rk3326_miniloader_v1.28.bin" | sha256sum -c - &&
  tools/mkimage -n px30 -T rksd -d rk3326_ddr_333MHz_v1.15.bin sd_fuse/idbloader.img &&
  cat rk3326_miniloader_v1.28.bin >> sd_fuse/idbloader.img
  verify_action
fi

dd if="sd_fuse/idbloader.img" of="../${DISK}" bs=512 seek=64 conv=sync,noerror,notrunc
dd if="sd_fuse/uboot.img" of="../${DISK}" bs=512 seek=16384 conv=sync,noerror,notrunc
dd if="sd_fuse/trust.img" of="../${DISK}" bs=512 seek=24576 conv=sync,noerror,notrunc
if [ "$UNIT" == "rg351mp" ] || [ "$UNIT" == "g350" ] || [ "$UNIT" == "a10mini" ] || [ "$UNIT" == "xumini" ]; then
  cp arch/arm/dts/${UNIT}-uboot.dtb /tmp/
fi
cd ..
rm -rf u-boot-${CHIPSET}
