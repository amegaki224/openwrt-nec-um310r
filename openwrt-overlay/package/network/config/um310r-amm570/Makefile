include $(TOPDIR)/rules.mk

PKG_NAME:=um310r-amm570
PKG_RELEASE:=4
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/um310r-amm570
  SECTION:=net
  CATEGORY:=Network
  TITLE:=NEC uM310R AM Telecom AMM570 LTE support
  DEPENDS:=+ppp +chat +i2c-tools +kmod-usb-acm +kmod-usb-serial +odhcp6c +luci-base
endef

define Package/um310r-amm570/description
 Board-specific LTE support for NEC Magnus uM310R with AM Telecom AMM570.
 Provides LTE power sequencing, USB serial binding, netifd PPP protocol
 integration and LuCI protocol configuration.
endef

define Build/Compile
endef

define Package/um310r-amm570/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/um310r-lte-power $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/usr/sbin/um310r-lte-at $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/usr/sbin/um310r-led-status $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/usr/sbin/um310r-ppp-up $(1)/usr/sbin/

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/um310r-leds $(1)/etc/init.d/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/um310r-leds $(1)/etc/config/

	$(INSTALL_DIR) $(1)/lib/netifd/proto
	$(INSTALL_BIN) ./files/lib/netifd/proto/amm570.sh $(1)/lib/netifd/proto/

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/95-um310r-amm570 $(1)/etc/uci-defaults/
	$(INSTALL_BIN) ./files/etc/uci-defaults/96-um310r-ipv6-rfc7278 $(1)/etc/uci-defaults/

	$(INSTALL_DIR) $(1)/www/luci-static/resources/protocol
	$(INSTALL_DATA) ./files/www/luci-static/resources/protocol/amm570.js \
		$(1)/www/luci-static/resources/protocol/amm570.js
endef

$(eval $(call BuildPackage,um310r-amm570))
