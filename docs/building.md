# Building the package yourself

You do not need this to install the firmware. It is for checking what is in the package,
or for changing it. You need a Linux PC and a backup of a stock camera, which the
installer makes for you: run it with `CHECK_ONLY=yes` in `settings.txt`.

## What you need

```bash
sudo apt install build-essential git wget cpio unzip rsync bc libncurses-dev \
                 squashfs-tools file gawk xz-utils zip python3
```

- [Buildroot 2025.02.18](https://buildroot.org/downloads/buildroot-2025.02.18.tar.gz)
- the toolchain and the kernel source from the
  [Tuya BSP](https://github.com/tuya/tuya-bsp-gpl-public-components):
  `arm-anykav500-linux-uclibcgnueabi.tar.gz` and `linux-4.4.192`

  ```bash
  git clone https://github.com/tuya/tuya-bsp-gpl-public-components.git tuya-bsp
  mkdir toolchain
  tar -xf tuya-bsp/arm-anykav500-linux-uclibcgnueabi.tar.gz -C toolchain
  ```

- the kernel as a tarball in `dl/` of this project, as
  [02-building.md](02-building.md) describes. The source bundle of each release has it too.

## Build

```bash
R=$(pwd)                                   # this project
BR=~/buildroot-2025.02.18
OUT=~/gt1pro-build
TC=~/toolchain/arm-anykav500-linux-uclibcgnueabi/arm-anykav500-linux-uclibcgnueabi
BACKUP=~/backup-030353000000               # from the card

# the vendor files, into folders git ignores
scripts/extract-vendor-blobs.sh $BACKUP/full.bin $R

# the toolchain looks for its libraries in /opt: make it run from where it is.
# Buildroot builds patchelf first 
make -C $BR O=$OUT BR2_EXTERNAL=$R gncc_gt1pro_defconfig
make -C $BR O=$OUT BR2_EXTERNAL=$R host-patchelf
python3 scripts/toolchain-rpath-fix.py $TC $OUT/host/bin/patchelf

# the firmware, takes about 20 minutes
installer/build-firmware.sh $BR $OUT $TC

# the static tools the installer runs on the camera
installer/build-tools.sh $OUT $BR/dl

# unpack the stock partitions once more for the checksums
mkdir stock
$OUT/host/bin/unsquashfs -d stock/root $BACKUP/mtd5.bin
$OUT/host/bin/unsquashfs -d stock/app $BACKUP/mtd7.bin

# the package, in dist/
installer/make-release.sh $OUT stock 1.1
```

`dist/sdcard` is what goes on the card. If you used the same sources and stock firmware
as the release, `images.sha256` has the same checksums for ROOTFS and APP. The kernel
differs in its build time stamp.

Keep `stock/`, `package/anyka-libs/lib`, `package/anyka-modules/files` and
`board/anyka/stock` to yourself: these are the vendor's files. `.gitignore` keeps them
out of git, `make-release.sh` keeps them out of the package and stops if it finds one.

## Where the licences come in

A release has the source code of everything in the package that needs it. See
[THIRD-PARTY.md](../THIRD-PARTY.md). To put that bundle together: `make legal-info` in
Buildroot (with the same `O=` and `BR2_EXTERNAL=`), which stops at the vendor kernel
after it saved the other packages, then `installer/make-sources.sh $OUT $BR 1.1`.
