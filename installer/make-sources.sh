#!/bin/bash
#
# make-sources.sh: put the source bundle of a release together.
#
#   usage: installer/make-sources.sh <buildroot-output-dir> <buildroot-dir> <version>
#
# Needs the output of "make legal-info" in <buildroot-output-dir>/legal-info. That
# target stops at the kernel, whose vendor tarball has no hash Buildroot knows,
# but the other packages are saved before that. The kernel tarball, the archives
# the installer tools are built from and the ipcd source (without the firmware
# dumps its repository also holds) are added here.
#
set -eu

O=$(readlink -f "${1:?usage: $0 <buildroot-output-dir> <buildroot-dir> <version>}")
BR=$(readlink -f "${2:?usage: $0 <buildroot-output-dir> <buildroot-dir> <version>}")
VERSION=${3:?usage: $0 <buildroot-output-dir> <buildroot-dir> <version>}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)

# no user or group names from the build machine in the archives
TAROPTS="--sort=name --owner=0 --group=0 --numeric-owner"

L=$O/legal-info
DIST=$REPO/dist
B=$DIST/gt1pro-rtsp-sources-$VERSION
rm -rf "$B"
mkdir -p "$B/buildroot-packages" "$B/installer-tools" "$B/ipcd"

for p in busybox dropbear libnl wpa_supplicant; do
    d=$(ls -d "$L/sources/$p-"* | head -1)
    [ -d "$d" ] || { echo "missing in legal-info: $p" >&2; exit 1; }
    cp -r "$d" "$B/buildroot-packages/"
done
cp -r "$L/licenses" "$B/licenses"
cp "$L/manifest.csv" "$B/"

# the kernel tarball, repacked so that it carries no owner names either
T=$(mktemp -d -p "$DIST")
trap 'rm -rf "$T"' EXIT
mkdir "$T/kernel"
tar -xzf "$REPO/dl/linux-ak-4.4.192.tar.gz" -C "$T/kernel"
tar $TAROPTS -C "$T/kernel" -czf "$B/linux-ak-4.4.192.tar.gz" $(ls "$T/kernel")
cp "$REPO/board/anyka/linux.config" "$B/linux.config"

find_archive() { find "$BR/dl" -name "$1" | head -1 | grep . || { echo "missing: $1" >&2; exit 1; }; }
cp "$(find_archive squashfs-tools-4.6.1.tar.gz)" "$(find_archive zlib-1.3.2.tar.xz)" "$B/installer-tools/"
cp "$HERE/busybox-static.config" "$B/installer-tools/"

# ipcd: the source tree, the licence and the patches; not the repository's
# firmware dumps and decompiled vendor libraries, and not the toolchain archive
# and the stock scripts next to the source tree
tar -xzf "$(find_archive 'ipcd-63e72fb0ac2ddc32f7a314d729d41cd60effd860*.tar.gz')" -C "$T" --strip-components=1
tar $TAROPTS -C "$T" -czf "$B/ipcd/ipcd-63e72fb0-src.tar.gz" LICENSE README.md src/ipcd
cp "$REPO/package/ipcd/"*.patch "$B/ipcd/"

cp "$REPO/configs/gncc_gt1pro_defconfig" "$B/"
cp "$REPO/THIRD-PARTY.md" "$B/README.md"
cp "$REPO/LICENSE" "$B/LICENSE-this-project.txt"

TAR=$DIST/gt1pro-rtsp-sources-$VERSION.tar
tar $TAROPTS -C "$DIST" -cf "$TAR" "gt1pro-rtsp-sources-$VERSION"
(cd "$DIST" && sha256sum "$(basename "$TAR")" > "$(basename "$TAR").sha256")
du -sh "$B" "$TAR" | cut -f1 | tr '\n' ' '; echo
