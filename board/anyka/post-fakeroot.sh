#!/bin/sh
set -e
TARGET_DIR="$1"
# one set of passwords and SSH host keys per camera, on the CONFIG partition: the
# image itself holds none. Done here because mkusers still edits /etc/shadow
# earlier in the build
rm -rf "$TARGET_DIR/etc/shadow" "$TARGET_DIR/etc/dropbear"
ln -s /etc/config/shadow "$TARGET_DIR/etc/shadow"
ln -s /etc/config/dropbear "$TARGET_DIR/etc/dropbear"
rm -f "$BINARIES_DIR/app.squashfs"
"$HOST_DIR/bin/mksquashfs" "$TARGET_DIR/usr" "$BINARIES_DIR/app.squashfs" \
  -noappend -comp xz -Xbcj arm -b 128K -all-root
rm -rf "$TARGET_DIR/usr"
mkdir -p "$TARGET_DIR/usr"
