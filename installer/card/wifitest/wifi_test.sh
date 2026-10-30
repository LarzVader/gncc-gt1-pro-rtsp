#!/bin/sh
# The stock firmware runs this file at power-on when the card has a folder named
# "wifitest", and then does not start its cloud application. It is a factory test
# hook. From here on we run from RAM with our own static BusyBox.
S=/mnt/rtsp-setup
W=/tmp/rtsp

mkdir -p $W
mount -t tmpfs -o size=24m tmpfs $W
mkdir -p $W/bin
cp $S/bin/busybox $W/bin/busybox
cp $S/bin/mksquashfs $W/bin/mksquashfs
cp $S/install.sh $W/install.sh
chmod 755 $W/bin/busybox $W/bin/mksquashfs
$W/bin/busybox --install -s $W/bin

cd /
exec $W/bin/busybox sh $W/install.sh

# only reached when the static BusyBox could not be started
echo "The installer could not start its tools on this camera. Nothing was changed." > /mnt/RESULT.txt
sync
