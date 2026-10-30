#!/bin/bash
#
# build-tools.sh: cross-compile the static ARM helpers the installer runs on
# the camera: BusyBox and mksquashfs. They run on the stock kernel and do not touch
# the stock libraries. mksquashfs compresses with gzip: xz needs more RAM than the
# camera has, and the flash has enough room for the larger images.
#
#   usage: installer/build-tools.sh <buildroot-output-dir> <download-dir>
#
# <buildroot-output-dir> holds the toolchain wrapper (host/bin) from a finished
# firmware build. <download-dir> holds busybox-1.37.0.tar.bz2,
# squashfs-tools-4.6.1.tar.gz and zlib-1.3.2.tar.xz; Buildroot's own dl/ folder
# has them after a build (in the subfolders busybox/, squashfs/ and libzlib/).
#
set -eu

B=$(readlink -f "${1:?usage: $0 <buildroot-output-dir> <download-dir>}")
DL=$(readlink -f "${2:?usage: $0 <buildroot-output-dir> <download-dir>}")
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$B/installer-tools"
SYS="$OUT/sysroot"
CROSS=arm-anykav500-linux-uclibcgnueabi
PATH="$B/host/bin:$PATH"
export PATH
JOBS=$(nproc)

find_archive() { find "$DL" -name "$1" | head -1 | grep . || { echo "missing: $1" >&2; exit 1; }; }

rm -rf "$OUT"
mkdir -p "$OUT/src" "$SYS" "$OUT/bin"

echo "== zlib"
tar -xJf "$(find_archive zlib-1.3.2.tar.xz)" -C "$OUT/src"
cd "$OUT/src/zlib-1.3.2"
CC="$CROSS-gcc" CFLAGS="-Os" AR="$CROSS-ar" RANLIB="$CROSS-ranlib" \
    ./configure --static --prefix="$SYS" >/dev/null
make -j"$JOBS" libz.a >/dev/null
make install >/dev/null

echo "== mksquashfs"
tar -xzf "$(find_archive squashfs-tools-4.6.1.tar.gz)" -C "$OUT/src"
cd "$OUT/src/squashfs-tools-4.6.1/squashfs-tools"
# the camera has 31 MB of RAM: allow -mem below the stock minimum of 16 MB.
sed -i 's/^#define SQUASHFS_LOWMEM.*/#define SQUASHFS_LOWMEM 16/' mksquashfs.h
grep -q '^#define SQUASHFS_LOWMEM 16$' mksquashfs.h
make -j"$JOBS" mksquashfs \
    CC="$CROSS-gcc" \
    GZIP_SUPPORT=1 XZ_SUPPORT=0 LZO_SUPPORT=0 LZ4_SUPPORT=0 ZSTD_SUPPORT=0 XATTR_SUPPORT=0 \
    COMP_DEFAULT=gzip \
    EXTRA_CFLAGS="-Os -I$SYS/include" \
    EXTRA_LDFLAGS="-static -L$SYS/lib" >/dev/null
"$CROSS-strip" mksquashfs
cp mksquashfs "$OUT/bin/mksquashfs"

echo "== busybox"
tar -xjf "$(find_archive busybox-1.37.0.tar.bz2)" -C "$OUT/src"
cd "$OUT/src/busybox-1.37.0"
cp "$HERE/busybox-static.config" .config
make -j"$JOBS" CROSS_COMPILE="$CROSS-" oldconfig </dev/null >/dev/null
make -j"$JOBS" CROSS_COMPILE="$CROSS-" busybox >/dev/null
"$CROSS-strip" busybox
cp busybox "$OUT/bin/busybox"

ls -l "$OUT/bin"
file "$OUT/bin/"* | cut -c1-130
