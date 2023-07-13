################################################################################
#
# rtl8723ds-bt-fw
#
################################################################################

RTL8723DS_BT_FW_VERSION = 2023-06-13
RTL8723DS_BT_FW_SITE = "$(BR2_EXTERNAL_LPI4A_PATH)/package/rtl8723ds-bt-fw/fw/"
RTL8723DS_BT_FW_SITE_METHOD = local

define RTL8723DS_BT_FW_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/lib/firmware/rtlbt/
	cp -vf $(@D)/* $(TARGET_DIR)/lib/firmware/rtlbt/
endef

$(eval $(generic-package))
