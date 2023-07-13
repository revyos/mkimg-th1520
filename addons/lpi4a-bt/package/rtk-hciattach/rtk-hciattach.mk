################################################################################
#
# rtk-hciattach
#
################################################################################

RTK_HCIATTACH_VERSION = 2023-06-13
RTK_HCIATTACH_SITE = "$(BR2_EXTERNAL_LPI4A_PATH)/package/rtk-hciattach/src/"
RTK_HCIATTACH_SITE_METHOD = local

define RTK_HCIATTACH_BUILD_CMDS
	$(TARGET_MAKE_ENV) CC=$(TARGET_CC) $(MAKE) -C $(@D)/
endef

define RTK_HCIATTACH_INSTALL_TARGET_CMDS
	$(INSTALL) -m 755 -D $(@D)/rtk_hciattach \
		$(TARGET_DIR)/usr/bin/rtk_hciattach
endef

$(eval $(generic-package))
