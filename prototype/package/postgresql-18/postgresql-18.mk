################################################################################
#
# postgresql
#
################################################################################

POSTGRESQL_18_VERSION = 18.1
POSTGRESQL_18_SOURCE = postgresql-$(POSTGRESQL_18_VERSION).tar.bz2
POSTGRESQL_18_SITE = https://ftp.postgresql.org/pub/source/v$(POSTGRESQL_18_VERSION)
POSTGRESQL_18_LICENSE = PostgreSQL
POSTGRESQL_18_LICENSE_FILES = COPYRIGHT
POSTGRESQL_18_CPE_ID_VENDOR = postgresql
POSTGRESQL_18_SELINUX_MODULES = postgresql
POSTGRESQL_18_INSTALL_STAGING = YES
POSTGRESQL_18_CONFIG_SCRIPTS = pg_config
POSTGRESQL_18_LDFLAGS = $(TARGET_LDFLAGS) $(TARGET_NLS_LIBS)
# We have to force invalid paths for xmllint and xsltproc, otherwise
# if detected they get used, even with -Ddocs=disabled and
# -Ddocs_pdf=disabled, and it causes build failures
POSTGRESQL_18_CONF_OPTS = \
	-Drpath=false \
	-Ddocs=disabled \
	-Ddocs_pdf=disabled \
	-DXMLLINT=/nowhere \
	-DXSLTPROC=/nowhere
POSTGRESQL_18_DEPENDENCIES = \
	$(TARGET_NLS_DEPENDENCIES) \
	host-bison \
	host-flex

ifeq ($(BR2_PACKAGE_POSTGRESQL_18_FULL),y)
POSTGRESQL_18_NINJA_OPTS += world
POSTGRESQL_18_INSTALL_TARGET_OPTS += DESTDIR=$(TARGET_DIR) install-world
POSTGRESQL_18_INSTALL_STAGING_OPTS += DESTDIR=$(STAGING_DIR) install-world
endif

ifeq ($(BR2_PACKAGE_READLINE),y)
POSTGRESQL_18_DEPENDENCIES += readline
POSTGRESQL_18_CONF_OPTS += -Dreadline=enabled
else
POSTGRESQL_18_CONF_OPTS += -Dreadline=disabled
endif

ifeq ($(BR2_PACKAGE_ZLIB),y)
POSTGRESQL_18_DEPENDENCIES += zlib
POSTGRESQL_18_CONF_OPTS += -Dzlib=enabled
else
POSTGRESQL_18_CONF_OPTS += -Dzlib=disabled
endif

ifeq ($(BR2_PACKAGE_TZDATA),y)
POSTGRESQL_18_DEPENDENCIES += tzdata
POSTGRESQL_18_CONF_OPTS += -Dsystem_tzdata=/usr/share/zoneinfo
else
POSTGRESQL_18_DEPENDENCIES += host-zic
POSTGRESQL_18_CONF_ENV += ZIC="$(ZIC)"
endif

ifeq ($(BR2_PACKAGE_OPENSSL),y)
POSTGRESQL_18_DEPENDENCIES += openssl
POSTGRESQL_18_CONF_OPTS += -Dssl=openssl
else
POSTGRESQL_18_CONF_OPTS += -Dssl=none
endif

ifeq ($(BR2_PACKAGE_OPENLDAP),y)
POSTGRESQL_18_DEPENDENCIES += openldap
POSTGRESQL_18_CONF_OPTS += -Dldap=enabled
else
POSTGRESQL_18_CONF_OPTS += -Dldap=disabled
endif

ifeq ($(BR2_PACKAGE_ICU),y)
POSTGRESQL_18_DEPENDENCIES += icu
POSTGRESQL_18_CONF_OPTS += -Dicu=enabled
else
POSTGRESQL_18_CONF_OPTS += -Dicu=disabled
endif

ifeq ($(BR2_PACKAGE_LIBXML2),y)
POSTGRESQL_18_DEPENDENCIES += libxml2
POSTGRESQL_18_CONF_OPTS += -Dlibxml=enabled
POSTGRESQL_18_CONF_ENV += XML2_CONFIG=$(STAGING_DIR)/usr/bin/xml2-config
else
POSTGRESQL_18_CONF_OPTS += -Dlibxml=disabled
endif

ifeq ($(BR2_PACKAGE_ZSTD),y)
POSTGRESQL_18_DEPENDENCIES += host-pkgconf zstd
POSTGRESQL_18_CONF_OPTS += -Dzstd=enabled
else
POSTGRESQL_18_CONF_OPTS += -Dzstd=disabled
endif

ifeq ($(BR2_PACKAGE_LZ4),y)
POSTGRESQL_18_DEPENDENCIES += host-pkgconf lz4
POSTGRESQL_18_CONF_OPTS += -Dlz4=enabled
else
POSTGRESQL_18_CONF_OPTS += -Dlz4=disabled
endif

# required for postgresql.service Type=notify
ifeq ($(BR2_PACKAGE_SYSTEMD),y)
POSTGRESQL_18_DEPENDENCIES += systemd
POSTGRESQL_18_CONF_OPTS += -Dsystemd=enabled
else
POSTGRESQL_18_CONF_OPTS += -Dsystemd=disabled
endif

POSTGRESQL_18_CFLAGS = $(TARGET_CFLAGS)

ifneq ($(BR2_TOOLCHAIN_HAS_GCC_BUG_43744)$(BR2_TOOLCHAIN_HAS_GCC_BUG_85180),)
POSTGRESQL_18_CFLAGS += -O0
endif

POSTGRESQL_18_CONF_ENV += CFLAGS="$(POSTGRESQL_18_CFLAGS)"

define POSTGRESQL_18_USERS
	postgres -1 postgres -1 * /var/lib/pgsql /bin/sh - PostgreSQL Server
endef

define POSTGRESQL_18_INSTALL_TARGET_FIXUP
	$(INSTALL) -dm 0700 $(TARGET_DIR)/var/lib/pgsql
	$(RM) -rf $(TARGET_DIR)/usr/lib/postgresql/pgxs
endef

POSTGRESQL_18_POST_INSTALL_TARGET_HOOKS += POSTGRESQL_18_INSTALL_TARGET_FIXUP

define POSTGRESQL_18_INSTALL_CUSTOM_PG_CONFIG
	$(INSTALL) -m 0755 -D package/postgresql/pg_config \
		$(STAGING_DIR)/usr/bin/pg_config
	$(SED) "s|@POSTGRESQL_CONF_OPTIONS@|$(POSTGRESQL_18_CONF_OPTS)|g" $(STAGING_DIR)/usr/bin/pg_config
	$(SED) "s|@POSTGRESQL_VERSION@|$(POSTGRESQL_18_VERSION)|g" $(STAGING_DIR)/usr/bin/pg_config
	$(SED) "s|@TARGET_CFLAGS@|$(TARGET_CFLAGS)|g" $(STAGING_DIR)/usr/bin/pg_config
	$(SED) "s|@TARGET_CC@|$(TARGET_CC)|g" $(STAGING_DIR)/usr/bin/pg_config
endef

POSTGRESQL_18_POST_INSTALL_STAGING_HOOKS += POSTGRESQL_18_INSTALL_CUSTOM_PG_CONFIG

define POSTGRESQL_18_INSTALL_INIT_SYSV
	$(INSTALL) -m 0755 -D package/postgresql/S50postgresql \
		$(TARGET_DIR)/etc/init.d/S50postgresql
endef

define POSTGRESQL_18_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 644 package/postgresql/postgresql.service \
		$(TARGET_DIR)/usr/lib/systemd/system/postgresql.service
endef

$(eval $(meson-package))