ONLINE_ADVISOR_VERSION = 1.0
ONLINE_ADVISOR_SOURCE = $(ONLINE_ADVISOR_VERSION).tar.gz
ONLINE_ADVISOR_SITE = https://github.com/knizhnik/online_advisor/archive/refs/tags
ONLINE_ADVISOR_LICENSE = PostgreSQL
ONLINE_ADVISOR_CONFIG_SCRIPTS = pg_config
ONLINE_ADVISOR_LDFLAGS = $(TARGET_LDFLAGS) $(TARGET_NLS_LIBS)
ONLINE_ADVISOR_DEPENDENCIES = postgresql-18 boost custom-postgis
ONLINE_ADVISOR_SUPPORTS_IN_SOURCE_BUILD = NO

define ONLINE_ADVISOR_BUILD_CMDS
	cd $(@D) && $(MAKE1) PG_CONFIG=$(STAGING_DIR)/usr/bin/pg_config $(TARGET_CONFIGURE_OPTS) PKGCONFIG="$(PKG_CONFIG_HOST_BINARY)" OPTFLAGS="" -C $(@D)
endef

define ONLINE_ADVISOR_INSTALL_TARGET_CMDS
	$(INSTALL) $(@D)/online_advisor.so $(TARGET_DIR)/usr/lib/postgresql
	$(INSTALL) $(@D)/online_advisor.control $(TARGET_DIR)/usr/share/postgresql/extension
	$(INSTALL) $(@D)/*.sql $(TARGET_DIR)/usr/share/postgresql/extension
endef

$(eval $(generic-package))