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
work. Your backup is on the card by then.

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

## Going back to the stock firmware

You need the folder `backup-<serial number>` the installer made.

**The easy way, with a running RTSP firmware:**

1. Copy your backup folder to the top folder of a FAT32 card, if it is not there.
2. Make a text file `restore-stock.txt` in the top folder of the card, with the name
   of the folder as its only line, like `backup-030353000000`.
3. Put the card in and power the camera on. After about two minutes it restarts with
   the stock firmware, including your old settings. `autoupdate.log` on the card
   tells you how it went.

Your stock firmware comes back with the old connection to the cloud. Take the card
out now, or the installer starts again if the `wifitest` folder is still on it.

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
