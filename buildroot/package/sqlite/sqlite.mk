################################################################################
#
# sqlite
#
################################################################################

SQLITE_VERSION = 3.44.2
SQLITE_TAR_VERSION = 3440200
SQLITE_SOURCE = sqlite-autoconf-$(SQLITE_TAR_VERSION).tar.gz
SQLITE_SITE = https://www.sqlite.org/2023
SQLITE_LICENSE = blessing
SQLITE_LICENSE_FILES = tea/license.terms
SQLITE_CPE_ID_VENDOR = sqlite
SQLITE_INSTALL_STAGING = YES

ifeq ($(BR2_PACKAGE_SQLITE_STAT4),y)
SQLITE_CFLAGS += -DSQLITE_ENABLE_STAT4
endif

ifeq ($(BR2_PACKAGE_SQLITE_ENABLE_COLUMN_METADATA),y)
SQLITE_CFLAGS += -DSQLITE_ENABLE_COLUMN_METADATA
endif

ifeq ($(BR2_PACKAGE_SQLITE_ENABLE_FTS3),y)
SQLITE_CFLAGS += -DSQLITE_ENABLE_FTS3
endif

ifeq ($(BR2_PACKAGE_SQLITE_ENABLE_JSON1),y)
SQLITE_CFLAGS += -DSQLITE_ENABLE_JSON1
endif

ifeq ($(BR2_PACKAGE_SQLITE_ENABLE_UNLOCK_NOTIFY),y)
SQLITE_CFLAGS += -DSQLITE_ENABLE_UNLOCK_NOTIFY
endif

ifeq ($(BR2_PACKAGE_SQLITE_SECURE_DELETE),y)
SQLITE_CFLAGS += -DSQLITE_SECURE_DELETE
endif

ifeq ($(BR2_PACKAGE_SQLITE_NO_SYNC),y)
SQLITE_CFLAGS += -DSQLITE_NO_SYNC
endif

SQLITE_CFLAGS += \
	-DSQLITE_DEFAULT_MEMSTATUS=0 \
	-DSQLITE_OMIT_COMPILEOPTION_DIAGS \
	-DSQLITE_OMIT_DECLTYPE \
	-DSQLITE_OMIT_DEPRECATED \
	-DSQLITE_OMIT_EXPLAIN \
	-DSQLITE_OMIT_JSON \
	-DSQLITE_OMIT_LOAD_EXTENSION \
	-DSQLITE_OMIT_PROGRESS_CALLBACK \
	-DSQLITE_OMIT_SHARED_CACHE \
	-DSQLITE_OMIT_TCL_VARIABLE \
	-DSQLITE_OMIT_TRACE \
	-DSQLITE_OMIT_UTF16

# Building with Microblaze Gcc 4.9 makes compiling to hang.
# Work around using -O0
ifeq ($(BR2_microblaze):$(BR2_TOOLCHAIN_GCC_AT_LEAST_5),y:)
SQLITE_CFLAGS += $(TARGET_CFLAGS) -O0
else
# fallback to standard -O3 when -Ofast is present to avoid -ffast-math
SQLITE_CFLAGS += $(subst -Ofast,-O3,$(TARGET_CFLAGS))
endif

SQLITE_CONF_ENV = CFLAGS="$(SQLITE_CFLAGS)"
SQLITE_CONF_OPTS += \
	--disable-dynamic-extensions \
	--disable-fts4 \
	--disable-fts5 \
	--disable-rtree

ifeq ($(BR2_STATIC_LIBS),y)
SQLITE_CONF_OPTS += --enable-dynamic-extensions=no
else
SQLITE_CONF_OPTS += --disable-static-shell
endif

ifeq ($(BR2_TOOLCHAIN_HAS_THREADS),y)
SQLITE_CONF_OPTS += --enable-threadsafe
else
SQLITE_CONF_OPTS += --disable-threadsafe
SQLITE_CFLAGS += -DSQLITE_THREADSAFE=0
endif

ifeq ($(BR2_PACKAGE_NCURSES)$(BR2_PACKAGE_READLINE),yy)
SQLITE_DEPENDENCIES += ncurses readline
SQLITE_CONF_OPTS += --disable-editline --enable-readline
else ifeq ($(BR2_PACKAGE_LIBEDIT),y)
SQLITE_DEPENDENCIES += libedit
SQLITE_CONF_OPTS += --enable-editline --disable-readline
else
SQLITE_CONF_OPTS += --disable-editline --disable-readline
endif

$(eval $(autotools-package))
$(eval $(host-autotools-package))
