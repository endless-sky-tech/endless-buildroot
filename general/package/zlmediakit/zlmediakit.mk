################################################################################
#
# zlmediakit
#
################################################################################

ZLMEDIAKIT_VERSION = 7.0
ZLMEDIAKIT_SITE = $(call github,ZLMediaKit,ZLMediaKit,$(ZLMEDIAKIT_VERSION))

ZLMEDIAKIT_LICENSE = MIT
ZLMEDIAKIT_LICENSE_FILES = LICENSE
ZLMEDIAKIT_INSTALL_STAGING = YES
ZLMEDIAKIT_DEPENDENCIES = openssl

$(eval $(cmake-package))
