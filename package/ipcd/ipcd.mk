################################################################################
#
# ipcd — local RTSP/ONVIF/PTZ camera app (with the PTZ + IR patches)
#
################################################################################

# tag v0.3.1-gk2, pinned to the reviewed commit
IPCD_VERSION = 63e72fb0ac2ddc32f7a314d729d41cd60effd860
IPCD_SITE = https://github.com/michelostojski/ipcd.git
IPCD_SITE_METHOD = git
IPCD_LICENSE = MIT
IPCD_LICENSE_FILES = LICENSE
# the repository also holds firmware dumps and decompiled vendor libraries: keep
# them out of the source bundle. See THIRD-PARTY.md for where the source is
IPCD_REDISTRIBUTE = NO

# ipcd links against the Anyka SDK blobs, so anyka-libs must be built and
# staged first.
IPCD_DEPENDENCIES = anyka-libs

# Link against the staged blobs (self-contained, reproducible — no external
# extraction path).
define IPCD_BUILD_CMDS
	$(TARGET_MAKE_ENV) \
		$(MAKE) -C $(@D)/src/ipcd \
		TOOLCHAIN="$(HOST_DIR)/bin" \
		LIB_DIR="$(STAGING_DIR)/usr/lib"
endef

define IPCD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/src/ipcd/ipcd $(TARGET_DIR)/usr/bin/ipcd
	$(INSTALL) -D -m 0755 $(STAGING_DIR)/usr/lib/librt.so $(TARGET_DIR)/lib/librt.so
endef

$(eval $(generic-package))
