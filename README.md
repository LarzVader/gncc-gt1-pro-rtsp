# RTSP firmware for the GNCC GT1 Pro

**[Deutsche Anleitung](README.de.md)**

Turn your GNCC GT1 Pro into a plain network camera: RTSP stream, no cloud, no app, no
account, no connection to the internet. All you need is a microSD card. You do not have
to open the camera or solder anything, and you do not need a Linux PC.

Copy the package to a card, enter your Wi-Fi, put the card in the camera, power it on,
and wait a quarter of an hour.

## What you get

- **H.264 over RTSP**: `rtsp://<camera>:8554/main` (2304×1296) and `/sub` (640×360),
  usable with VLC, ffmpeg, Frigate, Home Assistant, Scrypted, Blue Iris and others
- **ONVIF** device discovery
- **Night vision in black and white**: the IR LEDs and the IR filter switch by themselves
- **No way out**: the camera ignores the gateway and DNS server of your router, so it
  cannot reach the internet, even without a rule on your router
- **Its own passwords** on every camera, random unless you set them. There is no default
  password
- **SSH access** as root, as this is your camera
- **Microphone off** by default
- **A full backup** of the flash on your card before anything changes, and a simple way
  back to the stock firmware

## Is this for your camera?

| | |
| --- | --- |
| Camera | **GNCC GT1 Pro**, FCC ID 2A3PR-GT1 |
| Tested with | stock firmware 7.3.37 |
| Card | microSD, **FAT32**, at least 256 MB |
| Wi-Fi | 2.4 GHz with WPA2. WPA2/WPA3 mixed works, WPA3 only does not. |

The installer checks the camera first. If your camera is another model or has a firmware
it does not know, it stops and tells you, and it does not change anything. You can run
just this check by setting `CHECK_ONLY=yes` in `settings.txt`.

## Installation

**1. Download** the file `gt1pro-rtsp-sdcard-*.zip` from
[Releases](https://github.com/LarzVader/gncc-gt1-pro-rtsp/releases) and unpack it
directly onto the empty card, so that the folders `wifitest` and `rtsp-setup` are in the
top folder of the card.

**2. Enter your Wi-Fi** in the file `settings.txt` on the card:

```
WIFI_SSID=name of your network
WIFI_PASSWORD=your password
```

**3. Install.** Power off the camera, put the card in, power it on, and leave it alone
for about 3 minutes:

| LED | Meaning |
| --- | --- |
| Red, steady | backup and building, about 1 minute |
| Red, blinking fast | writing the firmware, about half a minute. **Do not unplug.** |
| Blue, blinking | new firmware is running and connecting to your Wi-Fi |
| **Blue, steady** | **done**, the camera is on your network |
| Red and blue in turns | stopped. `RESULT.txt` on the card tells you why. |

**4. Read the results.** Power off the camera, take out the card and put it into your
computer:

- `CAMERA-ACCESS-<serial number>.txt`: stream addresses and passwords
- `camera-ip.txt`: the address of the camera. You also find it in the device list of your
  router, under the name `gt1pro`.

**5. Copy the folder `backup-<serial number>` to your computer.** It is your only way back
to the stock firmware. It holds private data of your camera, like your old Wi-Fi password
and its cloud certificates: never share it.

Leave the card out from now on, the camera does not need it. The card holds your Wi-Fi
password and the passwords of the camera, so keep it safe or delete `settings.txt` and
`CAMERA-ACCESS-*.txt`.

More cameras? Use the same card again, one camera after the other.

## Watching the stream

```bash
ffplay -rtsp_transport tcp "rtsp://camera:PASSWORD@192.168.1.50:8554/main"
```

In VLC: *Media → Open Network Stream*, with the same address.

There is also a small web page at `http://<camera>/`, with the same user name and password.

## Good to know

- **Give the camera a fixed address** in your router, so its stream address stays the same.
- **The frame rate is about 6 frames per second** with the settings the package uses
  (`fps = 10`). They let the sensor expose longer at night, for a much less grainy image.
  With `fps = 15` you get about 9, with more grain at night. The reason for the gap
  between the setting and the real rate is not known yet.
- **At night the picture goes dark for about 5 seconds every 10 minutes.** The camera has no
  light sensor, so it switches its IR light off now and then to check whether it is day yet.
  `ir_peek_s` in `ipcd.conf` sets the interval in seconds.
- **RTSP runs over TCP only.** A request for UDP gets `461 Unsupported Transport`, and ffmpeg,
  VLC and the others then switch to TCP by themselves. Over Wi-Fi, UDP would only lose packets.
  `rtsp_udp = 1` in `ipcd.conf` allows UDP anyway.
- **The clock stays wrong** without an NTP server on your network, as the camera has no way
  to the internet. Set `NTP_SERVER` in `settings.txt` if you have one. This does not affect
  the video.
- **Night images are black and white.** IR light has no colour the sensor could show, only a
  lilac tint, so the firmware takes the colour out. It comes back by itself when the camera
  switches to day.
- **Do not press the reset button during operation.** It is only for the recovery at
  power-on.
- There is no setup portal: this firmware never opens an access point. Change your Wi-Fi with
  a file on the card, see [Troubleshooting](docs/troubleshooting.md#the-blue-led-keeps-blinking-the-camera-does-not-get-onto-the-wi-fi).

## If something goes wrong

Read [Troubleshooting and recovery](docs/troubleshooting.md). It also explains how to go back
to the stock firmware.

The installer never writes U-Boot, the part of the camera that starts everything. U-Boot has
an updater that works with the reset button no matter what else is in the flash, so an
installation that went wrong can almost always be repaired with a card.

## How it can be legal to do this

A firmware for this camera needs files that are not free, like the media libraries of the chip
vendor and the driver for the sensor. Nobody may publish those, so a ready-made firmware image
cannot exist. But they are already on your camera. So **this package holds no vendor files**:
it holds the free parts, and your camera puts the firmware together itself, from its own files.
The result is compared bit by bit with the tested firmware.

How that works, and what else is different from the stock firmware:
[How it works](docs/how-it-works.md). Do you want to build it yourself?
[Building](docs/building.md).

## Risks

You replace the firmware of a device, at your own risk and only on a camera you own. You lose
your warranty and the cloud functions of the app. The firmware runs on two cameras so far. The
installer and the way back to the stock firmware have been tested on one of them, with version
1.0, which is not much. If it worked or did not work on yours, please tell us in an
[issue](https://github.com/LarzVader/gncc-gt1-pro-rtsp/issues), with your firmware version.

## Thanks

This project stands on the work of others:

- **[akost-firmware](https://github.com/michelostojski/akost-firmware)** by Michel Ostojski
  (MIT): the free firmware for this chip, and support for this camera. This project is its fork.
  Everything hard was done there.
- **[ipcd](https://github.com/medevil84/ipcd)** by medevil (MIT): the program that does the actual
  camera work, with RTSP, ONVIF and the web page.
- **[thingino](https://github.com/themactep/thingino-firmware)**: the model for how a camera
  firmware should update itself.
- **[TECKIN-TC100 Anyka hacks](https://github.com/ThatUsernameAlreadyExist/TECKIN-TC100-Anyka-AK3918-camera-hacks)**:
  the SD card hook that opens the door without any tools.
- The GPL source drop of the [Tuya BSP](https://github.com/tuya/tuya-bsp-gpl-public-components):
  the kernel and the toolchain.
- Significant breakthroughs in this project, from the installer that builds the firmware on the
  camera to the fixes in `ipcd` and this documentation, were worked out together with an AI.

## License

The work in this project is under the [MIT license](LICENSE). The package also holds free software
by others, under its own licences: see [THIRD-PARTY.md](THIRD-PARTY.md). Each release has the source
code that comes with it.
