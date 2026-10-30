#!/bin/bash
#
# build-firmware.sh: build the firmware images with Buildroot.
#
#   usage: installer/build-firmware.sh <buildroot-dir> <output-dir> <toolchain-dir>
#
# <buildroot-dir> is an unpacked Buildroot 2025.02.18. <toolchain-dir> is the
# arm-anykav500-linux-uclibcgnueabi toolchain from the Tuya BSP (see
# docs/02-building.md). Vendor files must be extracted first, see
# scripts/extract-vendor-blobs.sh. Images end up in <output-dir>/images.
#
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
BR=$(readlink -f "${1:?usage: $0 <buildroot-dir> <output-dir> <toolchain-dir>}")
OUT=$(readlink -m "${2:?usage: $0 <buildroot-dir> <output-dir> <toolchain-dir>}")
TC=$(readlink -f "${3:?usage: $0 <buildroot-dir> <output-dir> <toolchain-dir>}")

[ -e "$HERE/package/anyka-libs/lib/libplat_mem.so" ] || {
    echo "vendor files missing, run scripts/extract-vendor-blobs.sh first" >&2; exit 1; }

make -C "$BR" O="$OUT" BR2_EXTERNAL="$HERE" gncc_gt1pro_defconfig
sed -i "s|^BR2_TOOLCHAIN_EXTERNAL_PATH=.*|BR2_TOOLCHAIN_EXTERNAL_PATH=\"$TC\"|" "$OUT/.config"
make -C "$BR" O="$OUT" BR2_EXTERNAL="$HERE" olddefconfig
make -C "$BR" O="$OUT" BR2_EXTERNAL="$HERE"
ls -l "$OUT/images"
