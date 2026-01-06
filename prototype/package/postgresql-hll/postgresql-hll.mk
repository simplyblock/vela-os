POSTGRESQL_HLL_VERSION = 2.19
POSTGRESQL_HLL_SOURCE = v$(POSTGRESQL_HLL_VERSION).tar.gz
POSTGRESQL_HLL_SITE = https://github.com/citusdata/postgresql-hll/archive/refs/tags
POSTGRESQL_HLL_LICENSE = PostgreSQL
POSTGRESQL_HLL_CONFIG_SCRIPTS = pg_config
POSTGRESQL_HLL_LDFLAGS = $(TARGET_LDFLAGS) $(TARGET_NLS_LIBS)
POSTGRESQL_HLL_DEPENDENCIES = postgresql-18
POSTGRESQL_HLL_SUPPORTS_IN_SOURCE_BUILD = NO

define POSTGRESQL_HLL_BUILD_CMDS
	cd $(@D) && $(MAKE1) PG_CONFIG=$(STAGING_DIR)/usr/bin/pg_config USE_PGXS=1 $(TARGET_CONFIGURE_OPTS) PKGCONFIG="$(PKG_CONFIG_HOST_BINARY)" OPTFLAGS="" -C $(@D)
endef

define POSTGRESQL_HLL_INSTALL_TARGET_CMDS
	$(INSTALL) $(@D)/prefix.so $(TARGET_DIR)/usr/lib/postgresql
	$(INSTALL) $(@D)/prefix.control $(TARGET_DIR)/usr/share/postgresql/extension
	$(INSTALL) $(@D)/*.sql $(TARGET_DIR)/usr/share/postgresql/extension
endef

$(eval $(generic-package))