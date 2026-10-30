#!/bin/bash
#
# make-release.sh: put the SD card package together.
#
#   usage: installer/make-release.sh <buildroot-output-dir> <stock-dir> <version>
#
# <buildroot-output-dir>  finished firmware build, with installer/build-tools.sh
#                         run on it
# <stock-dir>             the unpacked partitions of a stock camera, as root/
#                         (ROOTFS) and app/ (APP)
#
# The package holds no vendor file. Every file of the firmware that comes from
# the camera is taken out of the images here and listed in vendor-files.txt with
# its checksum; the installer takes it from the camera itself. Of <stock-dir>
# only those checksums end up in the package.
#
# The images are also built here once, complete, with the same options as on the
# camera. The installer compares its result with their checksums.
#
set -eu

O=$(readlink -f "${1:?usage: $0 <buildroot-output-dir> <stock-dir> <version>}")
STOCK=$(readlink -f "${2:?usage: $0 <buildroot-output-dir> <stock-dir> <version>}")
VERSION=${3:?usage: $0 <buildroot-output-dir> <stock-dir> <version>}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)

UNSQUASHFS=$O/host/bin/unsquashfs
MKSQUASHFS=$O/host/bin/mksquashfs
# same as in install.sh, except -mem: it does not change the result
OPTS="-noappend -comp gzip -Xcompression-level 9 -b 128K -all-root -no-xattrs -processors 1 -mkfs-time 0 -all-time 0 -quiet -no-progress"

DIST=$REPO/dist
CARD=$DIST/sdcard
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

rm -rf "$DIST"
mkdir -p "$CARD/wifitest" "$CARD/rtsp-setup/bin"

"$UNSQUASHFS" -q -n -no-xattrs -d "$T/root" "$O/images/rootfs.squashfs" >/dev/null
"$UNSQUASHFS" -q -n -no-xattrs -d "$T/app" "$O/images/app.squashfs" >/dev/null

# ---------------------------------------------------- list the vendor files ---

MANIFEST=$CARD/rtsp-setup/vendor-files.txt
{
    echo "# Files of the firmware that come from the camera itself."
    echo "# sha256, mode, path on the stock firmware, image, path in the image"
} > "$MANIFEST"

add_vendor() {  # <image> <path in the image> <path on the stock firmware> <file in stock-dir>
    [ -f "$4" ] || { echo "not in the stock firmware: $3" >&2; exit 1; }
    mode=$(stat -c %a "$T/$1/$2")
    hash=$(sha256sum "$4" | cut -d' ' -f1)
    echo "$hash $mode $3 $1 $2" >> "$MANIFEST"
    rm -f "$T/$1/$2"
    mkdir -p "$T/vendor/$1/$(dirname "$2")"
    cp "$4" "$T/vendor/$1/$2"
    chmod "$mode" "$T/vendor/$1/$2"
}

for f in "$T"/app/modules/*.ko; do
    n=${f##*/}
    add_vendor app "modules/$n" "/usr/modules/$n" "$STOCK/app/modules/$n"
done
for f in "$T"/app/lib/*; do
    n=${f##*/}
    if [ -f "$STOCK/app/lib/$n" ]; then
        add_vendor app "lib/$n" "/usr/lib/$n" "$STOCK/app/lib/$n"
    fi
done
add_vendor root lib/modules/ak_mci.ko /usr/modules/ak_mci.ko "$STOCK/app/modules/ak_mci.ko"
add_vendor root lib/modules/4.4.192V2.1/kernel/net/wireless/cfg80211.ko \
    /lib/modules/4.4.192V2.1/kernel/net/wireless/cfg80211.ko \
    "$STOCK/root/lib/modules/4.4.192V2.1/kernel/net/wireless/cfg80211.ko"
for f in "$T"/root/etc/isp_*.conf; do
    n=${f##*/}
    add_vendor root "etc/$n" "/etc/$n" "$STOCK/root/etc/$n"
done
echo "vendor files: $(grep -vc '^#' "$MANIFEST")"

# ------------------------------------------------------- nothing of it left? --

python3 -I - "$T" "$STOCK" <<'EOF'
import hashlib, os, sys
t, stock = sys.argv[1:3]
def files(r):
    for b, _, fs in os.walk(r):
        for f in fs:
            p = os.path.join(b, f)
            if os.path.isfile(p) and not os.path.islink(p):
                yield p
known = {}
for p in files(stock):
    if os.path.getsize(p) > 0:
        known[hashlib.sha256(open(p, 'rb').read()).hexdigest()] = p
names = set()
for d in ('app/lib', 'app/modules'):
    names.update(os.listdir(os.path.join(stock, d)))
bad = []
for image in ('root', 'app'):
    for p in files(os.path.join(t, image)):
        h = hashlib.sha256(open(p, 'rb').read()).hexdigest()
        if h in known:
            bad.append((p, 'same as stock ' + known[h]))
        elif os.path.basename(p) in names or p.endswith('.ko') or '/isp_' in p:
            bad.append((p, 'looks like a vendor file'))
for b in bad:
    print('VENDOR FILE LEFT:', *b, file=sys.stderr)
sys.exit(1 if bad else 0)
EOF
echo "checked: no stock file left in the images"

# ------------------------------------------------------------- the free parts --

pack() {  # <image>
    tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 -C "$T/$1" -c . \
        | xz -9e --check=crc32 --lzma2=preset=9e,dict=1MiB > "$CARD/rtsp-setup/$1.tar.xz"
}
pack root
pack app

# ------------------------------------------------ the images the camera builds -

# the same steps as on the camera, from the same archive
full_image() {  # <image> <output>
    mkdir -p "$T/full-$1"
    tar -xpJf "$CARD/rtsp-setup/$1.tar.xz" -C "$T/full-$1"
    : > "$T/pseudo-$1"
    grep -v '^#' "$MANIFEST" | while read -r hash mode src image dest; do
        [ "$image" = "$1" ] || continue
        echo "$dest f $mode 0 0 cat $T/vendor/$1/$dest" >> "$T/pseudo-$1"
    done
    "$MKSQUASHFS" "$T/full-$1" "$2" $OPTS -pf "$T/pseudo-$1" >/dev/null
}
full_image root "$T/root.sqsh4"
full_image app "$T/usr.sqsh4"
[ "$(stat -c %s "$T/root.sqsh4")" -le $((0x198000)) ] || { echo "ROOTFS image too big" >&2; exit 1; }
[ "$(stat -c %s "$T/usr.sqsh4")" -le $((0x3f4000)) ] || { echo "APP image too big" >&2; exit 1; }
{
    (cd "$T" && sha256sum root.sqsh4 usr.sqsh4)
    (cd "$O/images" && sha256sum uImage)
} > "$CARD/rtsp-setup/images.sha256"
ls -l "$T/root.sqsh4" "$T/usr.sqsh4" "$O/images/uImage" | awk '{print $5, $NF}' | sed "s|$T/||; s|$O/images/||"
# for comparing with what a camera built. These hold vendor files: never publish them
mkdir -p "$DIST/private"
cp "$T/root.sqsh4" "$T/usr.sqsh4" "$DIST/private/"

# ------------------------------------------------------------------ the rest ---

cp "$O/images/uImage" "$CARD/rtsp-setup/uImage"
cp "$O/installer-tools/bin/busybox" "$O/installer-tools/bin/mksquashfs" "$CARD/rtsp-setup/bin/"
cp "$HERE/card/wifitest/wifi_test.sh" "$CARD/wifitest/"
cp "$HERE/card/rtsp-setup/install.sh" "$CARD/rtsp-setup/"
cp "$HERE/card/settings.txt" "$HERE/card/README.txt" "$CARD/"
echo "$VERSION" > "$CARD/rtsp-setup/VERSION"
mkdir -p "$CARD/rtsp-setup/licenses"
cp "$REPO/LICENSE" "$CARD/rtsp-setup/licenses/LICENSE-this-project.txt"
cp "$REPO/THIRD-PARTY.md" "$CARD/rtsp-setup/licenses/"
find "$CARD" -name '*.sh' -exec sed -i 's/\r$//' {} +

ZIP=$DIST/gt1pro-rtsp-sdcard-$VERSION.zip
(cd "$CARD" && zip -q -r -X "$ZIP" .)
(cd "$DIST" && sha256sum "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
ls -l "$ZIP" | awk '{print $5, $NF}'
cat "$CARD/rtsp-setup/images.sha256"
