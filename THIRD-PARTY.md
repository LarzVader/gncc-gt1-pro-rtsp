# Third-party software

The work in this project (installer, board and init scripts, patches, documentation) is MIT,
see `LICENSE`. The SD card package also holds software by others. Each release has a source
bundle `gt1pro-rtsp-sources-<version>.tar` with the source of everything in it that asks for
that, and `installer/make-sources.sh` is what puts the bundle together.

## In the firmware the camera builds

| Component | Version | Licence | Source |
| --- | --- | --- | --- |
| Linux kernel | 4.4.192, Anyka/Tuya vendor tree | GPL-2.0 | `linux-ak-4.4.192.tar.gz` in the bundle, from the [Tuya BSP](https://github.com/tuya/tuya-bsp-gpl-public-components) |
| BusyBox | 1.37.0 | GPL-2.0 | bundle, `buildroot-packages/busybox-1.37.0/` |
| uClibc-ng | 1.0.28 | LGPL-2.1 | binary from the Tuya BSP toolchain; source at [uclibc-ng.org](https://uclibc-ng.org/) |
| libgcc, libatomic | GCC 4.9.4 | GPL-3.0 with GCC Runtime Library Exception | Tuya BSP toolchain; source at [gcc.gnu.org](https://gcc.gnu.org/) |
| ipcd | fork of medevil's ipcd, tag v0.3.1-gk2, commit 63e72fb0, plus `package/ipcd/*.patch` | MIT | bundle, `ipcd/`; [upstream](https://github.com/medevil84/ipcd), [fork](https://github.com/michelostojski/ipcd) |
| wpa_supplicant | 2.12 | BSD-3-Clause | bundle, `buildroot-packages/wpa_supplicant-2.12/` |
| dropbear | 2026.93 | MIT | bundle, `buildroot-packages/dropbear-2026.93/` |
| libnl | 3.11.0 | LGPL-2.1 | bundle, `buildroot-packages/libnl-3.11.0/` |
| Buildroot | 2025.02.18 | GPL-2.0 | build system, not in the firmware; [buildroot.org](https://buildroot.org/) |

The files that are **not** in the package, because they are not free and come from your own
camera: Anyka's media libraries (`libplat_*.so`, `libmpi_*.so`, `libak*.so`, `libapp_*.so`),
the kernel modules in `/usr/modules`, the vendor's `cfg80211.ko` and the sensor tuning
`isp_q03p_mipi_2lane_h3b.conf`. The installer lists them with their checksums in
`rtsp-setup/vendor-files.txt`.

## In the installer

| Component | Version | Licence | Source |
| --- | --- | --- | --- |
| BusyBox, static | 1.37.0, `installer/busybox-static.config` | GPL-2.0 | bundle, `buildroot-packages/busybox-1.37.0/` |
| squashfs-tools (`mksquashfs`), static | 4.6.1 | GPL-2.0 | bundle, `installer-tools/squashfs-tools-4.6.1.tar.gz` |
| zlib | 1.3.2 | zlib | bundle, `installer-tools/zlib-1.3.2.tar.xz` |

## This project builds on

- [akost-firmware](https://github.com/michelostojski/akost-firmware) by Michel Ostojski, MIT.
  This repository is a fork of it; see `docs/upstream-README.md`.
- [thingino](https://github.com/themactep/thingino-firmware) for the SD card update convention.
- The [TECKIN-TC100 Anyka hacks](https://github.com/ThatUsernameAlreadyExist/TECKIN-TC100-Anyka-AK3918-camera-hacks)
  for the SD card hook of the stock firmware.
