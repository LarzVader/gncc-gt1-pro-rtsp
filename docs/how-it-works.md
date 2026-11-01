# How it works

## The problem with publishing a firmware for this camera

A firmware for this camera needs files that are not free: the media libraries of the
SoC vendor, the kernel modules for sensor, ISP and Wi-Fi, and the image tuning of the
sensor. Nobody may publish them. A package with a ready-made firmware image would be
illegal, and without those files the camera shows no picture.

But these files are already on your camera. So this package holds only the free parts,
and the firmware is put together **on the camera**, from its own files.

## What happens when you power on

**The way in.** The stock firmware has a factory test hook. Its start script
`main.sh` looks at the SD card right after mounting it:

```sh
if test -d /mnt/wifitest ;then
    WIFI_TEST=1
...
if [ $WIFI_TEST = 1 ]; then
    /mnt/wifitest/wifi_test.sh
```

If that folder exists, it runs the script as root and **does not start the cloud
application** `anyka_ipc`. So the camera never goes online during the installation.
Nothing is soldered, opened or exploited, and the same hook works on every run.

**The tools.** `wifi_test.sh` copies a static BusyBox and `mksquashfs` to a RAM disk
and continues there, so that from now on nothing depends on the stock system.

**1. Checks.** Flash layout, kernel version, and the SHA-256 of every file it will
take from the camera, against `vendor-files.txt`. A camera that differs stops here. Only
`FORCE_UNKNOWN_FIRMWARE=yes` in `settings.txt` lets a camera with other vendor files go on.

**2. Backup.** All eight flash partitions go to `backup-<serial>/` on the card, plus
one `full.bin`. Each partition is compared with a second read of the flash after the
caches are dropped, so what gets checked is really on the card.

**3. Build.** For both images (ROOTFS and APP): unpack the free part from the card to
the RAM disk and run `mksquashfs`, which reads the vendor files straight from the
camera's flash. The camera has 31 MB of RAM, so nothing is copied that does not have to
be, one image is built at a time, it compresses with gzip instead of xz, and the result
goes to the card.

The result is compared with `images.sha256`. mksquashfs is deterministic: same files,
same options, same bytes. So the firmware on your camera is **bit for bit the firmware
that was tested**, even though nobody ever distributed it. A camera forced with
`FORCE_UNKNOWN_FIRMWARE=yes` is the exception.

**4. Settings.** Wi-Fi, passwords and camera settings go to the CONFIG partition, and
the rest of what is on there goes away: the old Wi-Fi password, the cloud certificates
and the identity of the camera. All of it is in the backup.

The passwords are generated here if you did not set your own. The SoC has no hardware
random generator and the kernel has seen next to nothing after boot, so the installer
first feeds in data that is unique to the camera (its flash contents, among them a
private key) and timing data from the work so far.

**5. Writing.** With the images in RAM, the installer stops what still runs from flash,
then writes APP, KERNEL and ROOTFS. Each one is read back and compared, with up to
three attempts. ROOTFS comes last, and it restarts right after.

One detail matters here: the system is still running from the ROOTFS it is overwriting.
That works as long as nothing has to be read from it again. `init` is asleep and its
code is in the page cache, so the installer must not drop the cache from this point on,
and it empties only the block device's buffers before reading back.

## What runs on the camera afterwards

| | |
| --- | --- |
| Base | Buildroot, BusyBox, uClibc-ng, read-only squashfs |
| Kernel | Linux 4.4.192 from the vendor's GPL drop, built from source |
| Video | [`ipcd`](https://github.com/medevil84/ipcd): RTSP, ONVIF, web page |
| Wi-Fi | `wpa_supplicant` from Buildroot, the vendor's kernel driver |
| Access | `dropbear` SSH |
| Vendor files | libraries, kernel modules, sensor tuning: taken from your camera |

The camera is on the network with these ports:

| Port | |
| --- | --- |
| TCP 8554 | RTSP, Digest authentication |
| TCP 80 | web page and API, Digest authentication |
| TCP 22 | SSH, only `root` with password |
| UDP 3702 | ONVIF device discovery |

## Why it cannot reach the internet

The DHCP client script takes address and netmask from your router and ignores the
gateway and the DNS server. The camera has no default route, so packets to anywhere
outside your network have no way to leave, even without a rule on your router.
`ipcd` asks no NTP server unless you set one, and its microphone is off by default.

## Differences from akost-firmware

This project is a fork of
[akost-firmware](https://github.com/michelostojski/akost-firmware), which did the hard
part: finding out how to run a free system on this SoC. Its documentation is still
here in `docs/`, and the original README is `docs/upstream-README.md`. Compared to it:

- The SD card installer, which builds the firmware on the camera. With akost-firmware
  you take a flash dump and build the firmware on a Linux PC.
- **Patches to `ipcd`**, in `package/ipcd/`:
  - `0001`: never fall back to an open access point when Wi-Fi is configured
  - `0002`: NTP only from your own setting
  - `0003`: microphone off by default
  - `0004`: WPA2 only, as WPA3 hung the connection on this driver
  - `0005`: fewer periodic statistics in the log, as without a card the log is in RAM: the
    line per video stream only for its first three intervals and for intervals without a
    frame. The line per playing connection every 5 seconds stays, see
    [the log without a card](troubleshooting.md#the-log-without-a-card).
  - `0006`: find the IR filter GPIOs, so that night vision works on the GT1 Pro
  - `0007`: send a host name with the DHCP request
  - `0008`: check for daylight every 10 minutes instead of every minute: each check is
    5 s of dark picture
  - `0009`: RTP over TCP only, unless `rtsp_udp = 1` is set: over Wi-Fi, UDP loses packets
  - `0010`: black and white at night, by setting the chroma gain of the ISP to 0: the same
    switch in the encoder kills the process on this camera
  - `0011`: HTTP Digest: the Authorization header must name the requested path, so a header
    overheard on the LAN does not pass on another POST such as `/api/auth`. RTSP stays as
    it was.
  - `0012`: a stream no longer stops when a frame ends exactly on RTP packet 65535: the
    counter then wraps to 0, which the code took for "out of memory"
  - `0013`: the log in RAM stays below about 2 MB: at 1 MB the file becomes `<file>.old` and
    a new one starts. A log on a card stays as it is. udhcpc now logs to syslog, which has
    its own limit.
  - `0014`: a restart of the capture no longer hangs: the stop waited for the watchdog
    thread, which never ends. If a stop takes longer than a minute, the camera restarts.
    Along with that, RTSP clients are disconnected at once, `sensor.init` runs at every start
    of the capture, with IR detection on a day or night mode forced by hand stays, the frame
    rate is limited to 30, and the web page refuses an RTSP port that is in use.
  - `0015`: RTSP sessions: RTCP from a player is skipped instead of filling the read buffer,
    responses no longer land in the middle of an RTP packet when the send buffer is full, and
    a connection ends when its stream cannot go on, after about 20 seconds without progress.
  - `0016`: the clock comes from the NTP server you set. `ipcd` asks it itself, at every start
    and once an hour, as the firmware has no `ntpd`.
- **A smaller image**, as there is no hostapd, no OpenSSL and no WPA3, and no setup
  portal: the camera never opens an access point.
- Vendor libraries the firmware does not use are left out, among them the debug servers
  and the factory client that can talk to the network.
- Passwords and SSH host keys per camera, on the CONFIG partition. The image holds none.
- The way back to the stock firmware with `restore-stock.txt`.

## Building it yourself

See [building.md](building.md).
