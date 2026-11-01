# Troubleshooting and recovery

Everything the installer does is written to the card: `RESULT.txt` says what
happened, `rtsp-setup/install.log` has the details. The log holds no passwords, no
serial number and no Wi-Fi name, so you can share it in an issue.

U-Boot is never written, by the installer or by the firmware. That is why almost
every situation below has a way out.

## The LED never turned red, or nothing appeared on the card

There is no `RESULT.txt` on the card, or the camera behaves as usual.

- The card must be formatted as **FAT32** with one partition. Cards over 32 GB
  usually come as exFAT, format them as FAT32 first.
- The files must be in the top folder of the card: `wifitest` and `rtsp-setup` are
  folders directly on the card, not inside another folder.
- The stock firmware looks for the card only once, right after power-on, and very
  early. Slow cards can miss that moment: try again, then try another card.
- Your stock firmware may not have the `wifitest` hook. Please open an issue with
  the firmware version your app shows.

Without the hook the stock firmware starts as usual. It does not harm the camera.

## Red and blue in turns: the installation stopped

Read `RESULT.txt`. It says what is wrong and whether the camera was changed. Most
messages mean that it was not.

| Message | What to do |
| --- | --- |
| `WIFI_SSID is empty`, `WIFI_PASSWORD must have 8 to 63 characters` | Correct `settings.txt` and power the camera off and on. |
| `different flash layout`, `another kernel`, `does not have the file` | This is not the camera the installer was made for. Please open an issue with your `install.log`. |
| `files of this camera's firmware differ from the tested one` | See below. |
| `The backup on the card differs from the flash` | The card is unreliable: use another one. |
| `Could not build the firmware image` | The camera ran out of memory, or the card has a problem. Please open an issue with your `install.log`. |

### Your stock firmware differs from the tested one

The installer knows the checksums of all files it takes from the camera, and it
refuses to go on when one differs: it has no way to know whether the result would
work. At this point it has changed nothing on the camera and has not made a backup yet.

Please open an issue with your `install.log`: the list of differing files is the
start of supporting your firmware.

You can also install anyway, with `FORCE_UNKNOWN_FIRMWARE=yes` in `settings.txt`.
This is a real experiment: the camera may start without Wi-Fi, without picture, or
not at all. You need the reset button way back described below, and your backup.

## The blue LED keeps blinking: the camera does not get onto the Wi-Fi

Most likely the Wi-Fi name or password is wrong, or the network is not one the
camera can use. It needs **2.4 GHz** and **WPA2**: a network with WPA3 only does not
work, a mixed WPA2/WPA3 network does.

The new firmware reads new Wi-Fi settings from the card at every start. Make a text
file named `wifi.conf` in the top folder of the card:

```
ssid=name of your network
psk=your password
```

Put the card in, power the camera on. The firmware copies the file to its own flash
and deletes it from the card. The same way works later, when your Wi-Fi changes.

`boot.log` and `ipcd.log` on the card show what the firmware did during the start.

## A stream stops now and then, and usually only a new connection brings it back

Up to version 1.1.1 a stream stops when a frame ends exactly on RTP packet 65535. That
happens about every three hours per connection, and other connections to the
camera keep running. The camera stops sending but keeps the connection open, so a player
only notices at its own timeout, if it has one. Whether it then connects again depends on
the player. `ipcd.log` on the card, or `/tmp/ipcd.log` and `/tmp/ipcd.log.old` on the camera
when no card is in, show `send failed, ending session`, which can also mean a real network problem. Version
1.1.2 fixes this.

Up to the same version, a player that sends RTCP over TCP lost its connection after some minutes,
GStreamer's `rtspsrc` after about 7.5, with sound after half of that. Since 1.1.2 that no longer
happens.

Since 1.1.2, `send failed, ending session` means that a player took no data for about 20 seconds,
usually because of the network. The camera then ends the connection, so the player learns about it and
can connect again. Before, it stopped sending and kept the connection open.

## The log without a card

Without a card, `ipcd` writes its log to `/tmp/ipcd.log`, which is in RAM. Each connection adds a
line every 5 seconds, about 0.8 MB a day. At 1 MB the file becomes `/tmp/ipcd.log.old` and a new
one starts, so the log takes at most about 2 MB of RAM. With two connections it keeps the last 15
to 30 hours. A restart of the camera empties it. Once the capture runs, stopping `ipcd` by hand
leads to one: it takes the camera off the Wi-Fi, and within about 20 seconds the watchdog restarts
the camera, as nothing feeds it any more.

Up to version 1.1.1 nothing limited the log. With two connections that never stop, the memory of a
GT1 Pro should run out after about 9 days. The stream will then probably stutter, and the watchdog
will probably restart the camera, which also empties the log. This is calculated from a three-hour
run and has not been watched.

With a card in the camera at power-on, the log goes to the card instead, where it has no limit, and
the log of the start before stays there as `ipcd.log.prev`. Use an empty FAT32 card, not the one that
holds your passwords.

## The picture goes away for a moment after you change the stream settings

Changing the frame rate, the bit rate, the GOP, the codec, the port, which streams are on or the
switch `Auto IR detection` on the web page restarts the capture. The camera closes the connections
at once, the picture is back after about 10 seconds, with a long GOP up to one GOP later, and
players connect again if they do that by themselves. With `Auto IR detection` on, at night it
starts in the day setting for some seconds, unless night is forced. With the switch off, the
restart leaves the IR light off, even when night is forced; turning the switch on again brings it
back.

The same happens when the camera loses its IP address for more than 20 seconds or gets new Wi-Fi
settings while it is online: it connects to the Wi-Fi again and then starts the capture again. After
a lost address that takes about half a minute in all, and without a router it lasts until the router
is back. After a lost address the camera cannot tell the players: a player only notices when it
next sends something or at its own timeout, if it has one. If stopping the capture ever takes
longer than a minute, the camera restarts itself.

The frame rate goes up to 30: above that the main stream no longer opens, and from about 35 no
stream delivers a picture. The web page refuses a higher value, and one saved by an older version
counts as 30. It also refuses an RTSP port that something else on the camera listens on.

Up to version 1.1.1 the stream stayed away in all of these cases until you powered the camera off
and on.

## I lost the password

Make `ipcd.conf` in the top folder of the card, and the firmware takes it over at the
next start, the same way as `wifi.conf`:

```
fps = 10
max_exp_lines = 2700
ir_d2n_lum = 6000
ir_n2d_lum = 1024
audio_in_enable = 0
http_user = camera
http_pass = your new password
```

The SSH password cannot be set this way. Go back to the stock firmware and install
again, see below.

## The camera does not start after an interrupted installation

If the power failed while the red LED was blinking fast, the flash is only partly
written. As long as the installation has not finished, the card still holds the
firmware files `uImage`, `root.sqsh4`, `usr.sqsh4` and `test_file`. U-Boot can write
them, and it works no matter what is in the flash after it:

1. Power the camera off, card inserted.
2. Hold the reset button.
3. Power the camera on and keep holding for about 10 seconds.
4. Wait two minutes, power it off and on again.

If the camera starts the stock firmware instead, U-Boot did not see the button:
power it off and try again, and hold the button a little longer before you plug in
the power.

## Updating from an older version

The installer only starts from the stock firmware, so an update goes through it. Unpack the new
package directly onto the card that holds the backup folder of this camera, enter your Wi-Fi in
`settings.txt`, and add `restore-stock.txt` as described in
[Going back to the stock firmware](#going-back-to-the-stock-firmware), but leave the folder
`wifitest` on the card. The camera then restores the stock firmware and installs the new version
right after it. `restore-stock.txt` becomes `restore-stock.done` before the restore starts, so
this happens only once. If the camera starts the old version again, the restore did not start:
`autoupdate.log` on the card normally says why, and the file is then called `restore-stock.bad`.
Correct the problem and name the file `restore-stock.txt` again.

What stays and what does not:

- The backup folder stays on the card as it is. The installer only replaces it if the file
  `BACKUP-OK` is missing from it.
- The new `settings.txt` replaces your old one, so enter again what you want to keep. If you
  needed `FORCE_UNKNOWN_FIRMWARE=yes` the first time, you need it again.
- Your passwords change unless you set them in `settings.txt`, and so do the user name and the
  NTP server. The access data are in `CAMERA-ACCESS-<serial number>.txt` on the card, as after a
  new installation.
- Other settings you changed on the camera go back to those of a new installation, such as the
  stream settings. SSH gets a new host key, so your SSH client will warn you.

What can go wrong on the way:

- The stock firmware looks for the card only once, very early. If it misses that moment, it
  starts as usual and goes online with your old settings, with the card still in it. `RESULT.txt`
  then still shows the result of your last installation. Power the camera off and on with the
  card inserted to try again.
- If the installer stops and `RESULT.txt` says the camera was not changed, that only counts from
  the start of the installer: the stock firmware is back. Correct the problem and power the
  camera off and on with the card inserted. You do not need `restore-stock.txt` again. If you
  start the camera without the card, it goes online with your old settings.

This way has been tested once, from 1.0 to 1.0, with a backup that held no Wi-Fi settings and no
cloud data of the stock firmware. A backup with real data has not been through this way yet.

## Going back to the stock firmware

You need the folder `backup-<serial number>` the installer made. The easy way wrote and checked
the stock firmware once, from a backup that held no Wi-Fi settings and no cloud data, and nobody
watched the stock firmware run afterwards. The reset button way was used with firmware images,
not with the files of a backup.

**The easy way, with a running RTSP firmware:**

1. Copy your backup folder to the top folder of a FAT32 card, if it is not there.
2. **Delete the folder `wifitest` from the card.** With it on the card, the installer
   starts again as soon as the stock firmware is back.
3. Make a text file `restore-stock.txt` in the top folder of the card, with the name
   of the folder as its only line, like `backup-030353000000`.
4. Put the card in and power the camera on. After about two minutes it restarts with
   the stock firmware, including your old settings. `autoupdate.log` on the card
   tells you how it went.

Your stock firmware comes back with your old Wi-Fi settings and its old connection to
the cloud, so it goes online again as soon as it has started.

**With the reset button, if the camera does not start any more:**

1. On your computer, copy these files from the backup folder to the top folder of a
   FAT32 card and rename them:

   | From the backup | Name on the card |
   | --- | --- |
   | `mtd4.bin` | `uImage` |
   | `mtd5.bin` | `root.sqsh4` |
   | `mtd7.bin` | `usr.sqsh4` |

2. Make a text file named `test_file` with any short text in it.
3. Hold the reset button, power on, keep holding for about 10 seconds. Wait two
   minutes.

This does not bring back the CONFIG partition with your settings and the cloud
certificates of the stock firmware. If the stock firmware is not happy without them,
use the easy way afterwards: install again first, and then restore.

**Never put `u-boot.bin` or `anyka_ev500.dtb` on such a card.** U-Boot would write
them, and a bad U-Boot can only be repaired with a flash programmer.

## Do not press the reset button during operation

The button is for the recovery above, at power-on. What it does while the firmware is
running comes from `ipcd`, and it can delete the Wi-Fi settings. The camera then waits
for a new `wifi.conf` from a card: this firmware never opens an access point.
