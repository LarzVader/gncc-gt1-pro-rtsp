#!/bin/sh
#
# install.sh: replace the stock firmware of a GNCC GT1 Pro with the RTSP firmware.
#
# Started by wifitest/wifi_test.sh, runs from RAM with a static BusyBox. In order:
#
#   1. check that this is the camera we know
#   2. save a full backup of the flash to the card
#   3. build the firmware images, from our free parts plus the vendor files that
#      are already on this camera
#   4. set up the CONFIG partition: Wi-Fi, passwords, camera settings
#   5. write KERNEL, APP and ROOTFS, check them, restart
#
# Until step 4 the camera is not changed at all. U-Boot is never touched, so the
# updater in U-Boot can bring back any state with the reset button.

CARD=/mnt
SETUP=$CARD/rtsp-setup
W=/tmp/rtsp
LOG=$SETUP/install.log
RESULT=$CARD/RESULT.txt
PATH=$W/bin
export PATH

SQUASHFS_OPTS="-noappend -comp gzip -Xcompression-level 9 -b 128K -all-root -no-xattrs -processors 1 -mkfs-time 0 -all-time 0 -mem 4M -quiet -no-progress"
CHANGED=no

# ------------------------------------------------------------------ messages --

log() {
    echo "[$(cut -d' ' -f1 /proc/uptime)] $*" >> "$LOG"
    sync
}

mem() {
    log "memory: $(free | sed -n 2p | tr -s ' ' | cut -d' ' -f4,7) kB free/available"
}

set_led() {
    echo "$1" > $W/led
}

leds() {
    echo "$1" > /sys/class/leds/red_led/brightness 2>/dev/null
    echo "$2" > /sys/class/leds/blue_led/brightness 2>/dev/null
}

# red steady: working. red blinking fast: writing the flash, do not unplug.
# red and blue in turns: stopped, see RESULT.txt. blue steady: check finished.
led_loop() {
    while :; do
        case "$(cat $W/led 2>/dev/null)" in
            flash) leds 1 0; sleep 0.2; leds 0 0; sleep 0.2 ;;
            error) leds 1 0; sleep 0.5; leds 0 1; sleep 0.5 ;;
            done)  leds 0 1; sleep 1 ;;
            *)     leds 1 0; sleep 1 ;;
        esac
    done
}

fail() {
    log "STOPPED: $*"
    {
        echo "THE INSTALLATION STOPPED"
        echo
        echo "$*"
        echo
        case $CHANGED in
            no)
                echo "The camera was not changed. Without this card it starts the stock firmware"
                echo "as before." ;;
            config)
                echo "The firmware was not replaced, but the settings partition was: the cloud"
                echo "application of the stock firmware may no longer work. You find the original"
                echo "in the backup folder on this card. To try again, power the camera off and on"
                echo "with this card inserted." ;;
            flash)
                echo "The flash may be only partly written, and the camera may not start any more."
                echo "Your way out: power it off, hold the reset button, power it on, and keep"
                echo "holding for 10 seconds. U-Boot then writes the files uImage, root.sqsh4 and"
                echo "usr.sqsh4 from this card. See docs/troubleshooting.md in the project." ;;
        esac
        echo
        echo "Details: rtsp-setup/install.log"
    } > "$RESULT"
    dmesg > "$SETUP/dmesg.txt" 2>/dev/null
    sync
    set_led error
    while :; do sleep 3600; done
}

# ---------------------------------------------------------------------- start --

set_led work
led_loop &
[ -f "$LOG" ] && mv -f "$LOG" "$LOG.previous"
: > "$LOG"
{
    echo "THE INSTALLATION IS RUNNING, OR IT WAS INTERRUPTED"
    echo
    echo "If the camera is off now, the installation did not finish. Power it on again"
    echo "with this card inserted."
} > "$RESULT"
log "installer started, kernel $(uname -r)"
mem
ps >> "$LOG"
killall cmd_serverd 2>/dev/null

# ------------------------------------------------------------- read settings --

[ -f $CARD/settings.txt ] || fail "settings.txt is missing from the card."
BOM=$(printf '\357\273\277')
tr -d '\r' < $CARD/settings.txt | sed "1s/^$BOM//" > $W/settings

setting() {
    sed -n "s/^$1=//p" $W/settings | head -n 1
}

WIFI_SSID=$(setting WIFI_SSID)
WIFI_PASSWORD=$(setting WIFI_PASSWORD)
RTSP_USER=$(setting RTSP_USER)
RTSP_PASSWORD=$(setting RTSP_PASSWORD)
ROOT_PASSWORD=$(setting ROOT_PASSWORD)
NTP_SERVER=$(setting NTP_SERVER)
CHECK_ONLY=$(setting CHECK_ONLY)
FORCE=$(setting FORCE_UNKNOWN_FIRMWARE)
[ -n "$RTSP_USER" ] || RTSP_USER=camera

url_safe() {
    case "$1" in
        *[!A-Za-z0-9._~-]*) return 1 ;;
    esac
    return 0
}

[ -n "$WIFI_SSID" ] || fail "settings.txt: WIFI_SSID is empty. Enter the name of your Wi-Fi."
[ ${#WIFI_SSID} -le 32 ] || fail "settings.txt: WIFI_SSID is longer than 32 characters."
[ ${#WIFI_PASSWORD} -ge 8 ] && [ ${#WIFI_PASSWORD} -le 63 ] || \
    fail "settings.txt: WIFI_PASSWORD must have 8 to 63 characters. The camera needs a network with WPA2."
url_safe "$RTSP_USER" || fail "settings.txt: RTSP_USER may only have letters, digits and - _ . ~"
url_safe "$RTSP_PASSWORD" || fail "settings.txt: RTSP_PASSWORD may only have letters, digits and - _ . ~"
url_safe "$ROOT_PASSWORD" || fail "settings.txt: ROOT_PASSWORD may only have letters, digits and - _ . ~"
url_safe "$NTP_SERVER" || fail "settings.txt: NTP_SERVER may only have letters, digits and - _ . ~"
log "settings read"

# ----------------------------------------------------- is this our camera? ----

EXPECTED_MTD='mtd0: 00040000 00001000 "UBOOT"
mtd1: 00001000 00001000 "ENV"
mtd2: 00001000 00001000 "ENVBK"
mtd3: 0000c000 00001000 "DTB"
mtd4: 001c2000 00001000 "KERNEL"
mtd5: 00198000 00001000 "ROOTFS"
mtd6: 00064000 00001000 "CONFIG"
mtd7: 003f4000 00001000 "APP"'

[ "$(grep '^mtd' /proc/mtd)" = "$EXPECTED_MTD" ] || {
    cat /proc/mtd >> "$LOG"
    fail "This camera has a different flash layout, so it is not the model this installer is made for."
}
[ "$(uname -r)" = "4.4.192V2.1" ] || fail "This camera runs another kernel ($(uname -r)), so it is not the model this installer is made for."

FREE_KB=$(df -k $CARD | sed -n 2p | tr -s ' ' | cut -d' ' -f4)
[ "${FREE_KB:-0}" -ge 40960 ] || fail "The card needs at least 40 MB of free space."

MANIFEST=$SETUP/vendor-files.txt
[ -f "$MANIFEST" ] || fail "rtsp-setup/vendor-files.txt is missing. Copy the whole package to the card again."
mismatch=0
while read -r hash mode src image dest; do
    case "$hash" in ''|'#'*) continue ;; esac
    [ -f "$src" ] || fail "This camera does not have the file $src, so it is not the model this installer is made for."
    got=$(sha256sum < "$src" | cut -d' ' -f1)
    if [ "$got" != "$hash" ]; then
        log "differs from the tested firmware: $src"
        mismatch=$((mismatch+1))
    fi
done < "$MANIFEST"
if [ $mismatch != 0 ]; then
    [ "$FORCE" = yes ] || fail "$mismatch files of this camera's firmware differ from the tested one (listed in rtsp-setup/install.log). Please report this in the project, so that the firmware can be tested. To install anyway, read docs/troubleshooting.md first."
    log "$mismatch files differ, going on because of FORCE_UNKNOWN_FIRMWARE=yes"
else
    log "vendor files are the tested ones"
fi
mem

# --------------------------------------------------------------- backup -------

camera_id() {
    id=$(cat /etc/config/backup-id 2>/dev/null)
    [ -n "$id" ] || id=$(tr -cd 'A-Za-z0-9_-' < /etc/config/sn.txt 2>/dev/null | cut -c1-32)
    [ -n "$id" ] || id=$(tr -cd 'A-Fa-f0-9' < /etc/config/wifimac.txt 2>/dev/null | cut -c1-12)
    [ -n "$id" ] || id=unknown-$(head -c 4 /dev/urandom | hexdump -v -e '4/1 "%02x"')
    echo "$id"
}

ID=$(camera_id)
BACKUP=$CARD/backup-$ID

if [ -f "$BACKUP/BACKUP-OK" ]; then
    log "backup already on the card, keeping it"
else
    log "saving the backup"
    rm -rf "$BACKUP"
    mkdir -p "$BACKUP" || fail "Could not write to the card."
    for n in 0 1 2 3 4 5 6 7; do
        cat /dev/mtdblock$n > "$BACKUP/mtd$n.bin" || fail "Could not save the backup to the card."
    done
    (cd "$BACKUP" && cat mtd0.bin mtd1.bin mtd2.bin mtd3.bin mtd4.bin mtd5.bin mtd6.bin mtd7.bin > full.bin) \
        || fail "Could not save the backup to the card."
    sync
    # compare what is really on the card with a second read of the flash
    echo 3 > /proc/sys/vm/drop_caches
    for n in 0 1 2 3 4 5 6 7; do
        cmp /dev/mtdblock$n "$BACKUP/mtd$n.bin" || fail "The backup on the card differs from the flash. The card may be bad, try another one."
    done
    [ "$(wc -c < "$BACKUP/full.bin")" = 8388608 ] || fail "The backup on the card has the wrong size."
    (cd "$BACKUP" && sha256sum mtd0.bin mtd1.bin mtd2.bin mtd3.bin mtd4.bin mtd5.bin mtd6.bin mtd7.bin full.bin > SHA256SUMS) \
        || fail "Could not save the backup to the card."
    echo "$ID" > "$BACKUP/BACKUP-OK"
    sync
    log "backup saved and checked"
fi
mem

# -------------------------------------------------------- build the images ----

build_image() {  # <image name> <output file>
    tree=$W/tree
    rm -rf $tree
    mkdir -p $tree
    xzcat "$SETUP/$1.tar.xz" | tar -xf - -C $tree || fail "Could not unpack $1.tar.xz. Copy the whole package to the card again."
    # the vendor files are not copied into RAM: mksquashfs reads each one from the
    # camera's own flash through "cat" (a pseudo file definition)
    pseudo=$W/pseudo
    : > $pseudo
    while read -r hash mode src image dest; do
        case "$hash" in ''|'#'*) continue ;; esac
        [ "$image" = "$1" ] || continue
        mkdir -p "$tree/${dest%/*}"
        echo "$dest f $mode 0 0 cat $src" >> $pseudo
    done < "$MANIFEST"
    mem
    rm -f "$2"
    mksquashfs $tree "$2" $SQUASHFS_OPTS -pf $pseudo >> "$LOG" 2>&1 || {
        mem
        fail "Could not build the firmware image $1."
    }
    rm -rf $tree $pseudo
    sync
    mem
}

image_ok() {  # <file> <name in images.sha256>
    want=$(sed -n "s/^\([0-9a-f]*\)  $2\$/\1/p" "$SETUP/images.sha256")
    got=$(sha256sum < "$1" | cut -d' ' -f1)
    log "$2: $got"
    [ -n "$want" ] && [ "$got" = "$want" ]
}

fits() {  # <file> <partition size>
    size=$(wc -c < "$1")
    [ "$size" -gt 0 ] && [ "$size" -le "$2" ]
}

log "building the ROOTFS image"
build_image root $CARD/root.sqsh4
log "building the APP image"
build_image app $CARD/usr.sqsh4
cp "$SETUP/uImage" $CARD/uImage || fail "Could not copy uImage to the card."
sync

fits $CARD/root.sqsh4 $((0x198000)) || fail "The ROOTFS image does not fit its partition."
fits $CARD/usr.sqsh4 $((0x3f4000)) || fail "The APP image does not fit its partition."
fits $CARD/uImage $((0x1c2000)) || fail "The kernel does not fit its partition."

same=yes
image_ok $CARD/root.sqsh4 root.sqsh4 || same=no
image_ok $CARD/usr.sqsh4 usr.sqsh4 || same=no
image_ok $CARD/uImage uImage || same=no
if [ $same = yes ]; then
    log "the images are exactly the tested ones"
elif [ "$FORCE" = yes ] && [ $mismatch != 0 ]; then
    log "the images differ from the tested ones, as expected with other vendor files"
else
    fail "The firmware images built on this camera differ from the tested ones (although the vendor files are the same). The card may be bad, or the camera ran out of memory."
fi

if [ "$CHECK_ONLY" = yes ]; then
    rm -f $CARD/root.sqsh4 $CARD/usr.sqsh4 $CARD/uImage
    {
        echo "CHECK FINISHED, NOTHING WAS INSTALLED"
        echo
        echo "This camera is compatible, and a backup of its flash is in the folder"
        echo "backup-$ID on this card. Copy that folder to your computer."
        echo
        echo "To install: set CHECK_ONLY=no in settings.txt, then power the camera off and on"
        echo "with this card inserted."
    } > "$RESULT"
    sync
    log "check finished, nothing was installed"
    set_led done
    while :; do sleep 3600; done
fi

# with these and the reset button, U-Boot can finish the job if the power fails below
echo "rtsp" > $CARD/test_file
sync

# ------------------------------------------------------------- CONFIG partition

# Device-unique data and timing for the random generator: this SoC has no hardware
# generator, and early after boot the kernel has seen next to nothing yet.
{
    cat /dev/mtdblock6 /dev/mtdblock1
    cat /proc/interrupts /proc/stat /proc/uptime /proc/meminfo /proc/diskstats
    date
} > /dev/urandom 2>/dev/null

random_password() {
    head -c 512 /dev/urandom | tr -dc 'a-zA-Z0-9' | cut -c1-20
}

[ -n "$RTSP_PASSWORD" ] || RTSP_PASSWORD=$(random_password)
[ -n "$ROOT_PASSWORD" ] || ROOT_PASSWORD=$(random_password)
[ ${#RTSP_PASSWORD} -ge 8 ] && [ ${#ROOT_PASSWORD} -ge 8 ] || fail "Could not create the passwords (they need at least 8 characters)."
ROOT_HASH=$(mkpasswd -m sha256 "$ROOT_PASSWORD")
case "$ROOT_HASH" in '$5$'*) ;; *) fail "Could not create the password for SSH." ;; esac

MAC=$(cat /etc/config/wifimac.txt 2>/dev/null | tr -d '\r\n ')
ACCESS="$CARD/CAMERA-ACCESS-$ID.txt"
{
    echo "GT1 Pro RTSP firmware: access data of this camera. Keep this file private."
    echo
    echo "Serial number:  $ID"
    echo "Wi-Fi MAC:      ${MAC:-unknown}"
    echo
    echo "Main stream:    rtsp://$RTSP_USER:$RTSP_PASSWORD@CAMERA-ADDRESS:8554/main"
    echo "Sub stream:     rtsp://$RTSP_USER:$RTSP_PASSWORD@CAMERA-ADDRESS:8554/sub"
    echo "Web page:       http://CAMERA-ADDRESS/  (same user and password)"
    echo "SSH:            ssh root@CAMERA-ADDRESS  password: $ROOT_PASSWORD"
    echo
    echo "CAMERA-ADDRESS: see camera-ip.txt on this card, or the device named gt1pro"
    echo "in the device list of your router."
} > "$ACCESS" || fail "Could not write to the card."
sync

log "setting up the CONFIG partition"
CHANGED=config
C=/etc/config
for f in $C/* $C/.[!.]*; do
    case "${f##*/}" in
        wifimac.txt|isp_*.conf|'*'|'.[!.]*') ;;
        *) rm -rf "$f" ;;
    esac
done
sync

umask 077
{
    printf 'ssid=%s\npsk=%s\n' "$WIFI_SSID" "$WIFI_PASSWORD" > $C/wifi.conf
    {
        echo "fps = 10"
        echo "max_exp_lines = 2700"
        echo "ir_d2n_lum = 6000"
        echo "ir_n2d_lum = 1024"
        echo "audio_in_enable = 0"
        echo "http_user = $RTSP_USER"
        echo "http_pass = $RTSP_PASSWORD"
    } > $C/ipcd.conf
    echo "--main-kbps 2000" > $C/ipcd.args
    echo "i2ctransfer -f -y 0 w2@0x40 0x12 0x30" > $C/sensor.init
    echo "root:$ROOT_HASH:::::::" > $C/shadow
    echo "$ID" > $C/backup-id
    head -c 512 /dev/urandom > $C/seed
    [ -z "$NTP_SERVER" ] || echo "$NTP_SERVER" > $C/ntp_server
} || fail "Could not write the settings to the CONFIG partition."
sync
grep -q "^ssid=" $C/wifi.conf && grep -q "^http_pass" $C/ipcd.conf && grep -q '^root:' $C/shadow \
    || fail "The settings did not arrive on the CONFIG partition."
log "CONFIG partition ready"
mem

# ------------------------------------------------------------ write the flash -

# From here on nothing may run from ROOTFS or APP. Do not drop the page cache once
# ROOTFS is written either: init would read its code back from the new data.
log "writing the flash"
set_led flash
CHANGED=flash

mkdir -p $W/img
cp $CARD/usr.sqsh4 $CARD/root.sqsh4 $CARD/uImage $W/img/ || fail "Could not load the firmware images into memory."
echo > /proc/sys/kernel/hotplug
killall cmd_serverd wpa_supplicant udhcpc 2>/dev/null
umount /usr 2>/dev/null || umount -l /usr

write_part() {  # <file> <mtd number>
    want=$(sha256sum < "$1" | cut -d' ' -f1)
    size=$(wc -c < "$1")
    try=0
    while [ $try -lt 3 ]; do
        try=$((try+1))
        dd if="$1" of=/dev/mtdblock$2 bs=4096 conv=fsync 2>/dev/null
        sync
        blockdev --flushbufs /dev/mtdblock$2
        got=$(head -c "$size" /dev/mtdblock$2 | sha256sum | cut -d' ' -f1)
        if [ "$got" = "$want" ]; then
            log "mtd$2 written and checked, attempt $try"
            return 0
        fi
        log "mtd$2 differs after attempt $try"
    done
    return 1
}

write_part $W/img/usr.sqsh4 7 || fail "Could not write the APP partition."
write_part $W/img/uImage 4 || fail "Could not write the KERNEL partition."
write_part $W/img/root.sqsh4 5 || fail "Could not write the ROOTFS partition."

# ------------------------------------------------------------------- finished -

rm -f $CARD/test_file $CARD/root.sqsh4 $CARD/usr.sqsh4 $CARD/uImage
{
    echo "THE FIRMWARE IS INSTALLED"
    echo
    echo "The camera restarted by itself. The blue LED blinks while it connects to your"
    echo "Wi-Fi and stays on once it is connected. That takes about a minute."
    echo
    echo "Then: power the camera off, take out this card, and read on your computer:"
    echo "  CAMERA-ACCESS-$ID.txt   the stream addresses and passwords"
    echo "  camera-ip.txt           the address of the camera"
    echo
    echo "Copy the folder backup-$ID to your computer. It is your only way back to the"
    echo "stock firmware. It holds private data of this camera, so keep it private."
    echo
    echo "If the LED keeps blinking, the Wi-Fi name or password may be wrong: see the"
    echo "project's docs/troubleshooting.md."
} > "$RESULT"
log "finished, restarting"
sync
cd /
umount $CARD 2>/dev/null
sync
sleep 1
reboot -f
