include $(sort $(wildcard $(BR2_EXTERNAL_ANYKA_PATH)/package/*/*.mk))

# The kernel should not say who built it and where. Buildroot does this only with
# BR2_REPRODUCIBLE, which changes more than that. With the fixed time stamp the same
# source and toolchain give the same uImage.
LINUX_MAKE_ENV += \
	KBUILD_BUILD_VERSION=1 \
	KBUILD_BUILD_USER=buildroot \
	KBUILD_BUILD_HOST=buildroot \
	KBUILD_BUILD_TIMESTAMP="$(shell LC_ALL=C TZ=UTC date -d @1793396383)" \
	SOURCE_DATE_EPOCH=1793396383
