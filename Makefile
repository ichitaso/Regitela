DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64

TARGET = iphone:clang:latest:17.0

PACKAGE_FORMAT = none

XCODEPROJ_NAME = Regitela

export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

PACKAGE_VERSION := $(shell grep -m1 'MARKETING_VERSION' $(XCODEPROJ_NAME).xcodeproj/project.pbxproj | sed -E 's/.*= *"?([^";]*)"?;.*/\1/')
IPA_NAME = Regitela_$(PACKAGE_VERSION).ipa

DEB_ID = com.ichitaso.regitela
DEB_NAME = $(DEB_ID)_$(PACKAGE_VERSION)_iphoneos-arm64.deb
DEB_ROOT = $(THEOS_STAGING_DIR)/deb

$(XCODEPROJ_NAME)_XCODEFLAGS = IPHONEOS_DEPLOYMENT_TARGET=17.0
$(XCODEPROJ_NAME)_CODESIGN_FLAGS = -SRegitela/Regitela.entitlements

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/xcodeproj.mk

after-package::
	@echo "Creating $(IPA_NAME)..."
	rm -rf $(THEOS_STAGING_DIR)/Payload
	mkdir -p $(THEOS_STAGING_DIR)/Payload $(THEOS_PACKAGE_DIR)
	cp -a $(THEOS_STAGING_DIR)/Applications/$(XCODEPROJ_NAME).app $(THEOS_STAGING_DIR)/Payload/
	rm -f $(THEOS_PACKAGE_DIR)/$(IPA_NAME)
	cd $(THEOS_STAGING_DIR) && zip -qry9 $(THEOS_PROJECT_DIR)/$(THEOS_PACKAGE_DIR)/$(IPA_NAME) Payload
	@echo "Creating $(DEB_NAME)..."
	rm -rf $(DEB_ROOT)
	mkdir -p $(DEB_ROOT)/DEBIAN $(DEB_ROOT)/var/jb/Applications
	cp -a $(THEOS_STAGING_DIR)/Applications/$(XCODEPROJ_NAME).app $(DEB_ROOT)/var/jb/Applications/
	ldid -SRegitela/jailbreak.entitlements $(DEB_ROOT)/var/jb/Applications/$(XCODEPROJ_NAME).app/$(XCODEPROJ_NAME)
	printf '%s\n' \
		"Package: $(DEB_ID)" \
		"Name: Regitela" \
		"Version: $(PACKAGE_VERSION)" \
		"Architecture: iphoneos-arm64" \
		"Description: worse_query based file explorer with Supervised Mode and Region tweaks" \
		"Maintainer: ichitaso" \
		"Author: ichitaso" \
		"Section: Applications" \
		"Depends: firmware (>= 17.0), uikittools" \
		> $(DEB_ROOT)/DEBIAN/control
	printf '#!/bin/sh\nuicache -p /var/jb/Applications/$(XCODEPROJ_NAME).app\nexit 0\n' > $(DEB_ROOT)/DEBIAN/postinst
	printf '#!/bin/sh\nif [ "$$1" = remove ] || [ "$$1" = purge ]; then\n\tuicache -u /var/jb/Applications/$(XCODEPROJ_NAME).app\nfi\nexit 0\n' > $(DEB_ROOT)/DEBIAN/prerm
	chmod 755 $(DEB_ROOT)/DEBIAN/postinst $(DEB_ROOT)/DEBIAN/prerm
	rm -f $(THEOS_PACKAGE_DIR)/$(DEB_NAME)
	$(THEOS_BIN_PATH)/dm.pl -Zgzip -b $(DEB_ROOT) $(THEOS_PACKAGE_DIR)/$(DEB_NAME)

clean::
	rm -rf $(THEOS_PACKAGE_DIR)
