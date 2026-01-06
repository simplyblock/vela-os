CUSTOM_POSTGIS_VERSION = 3.6.1
CUSTOM_POSTGIS_SOURCE = postgis-$(CUSTOM_POSTGIS_VERSION).tar.gz
CUSTOM_POSTGIS_SITE =  https://download.osgeo.org/postgis/source
CUSTOM_POSTGIS_LICENSE = GPL-2.0+ (PostGIS), BSD-3-Clause (xsl), GPL-2.0+ or LGPL-3.0+ (SFCGAL), MIT, Apache-2.0, ISC, BSL-1.0, CC-BY-SA-3.0
CUSTOM_POSTGIS_LICENSE_FILES = LICENSE.TXT
CUSTOM_POSTGIS_CONFIG_SCRIPTS = pg_config
CUSTOM_POSTGIS_LDFLAGS = $(TARGET_LDFLAGS) $(TARGET_NLS_LIBS)
CUSTOM_POSTGIS_DEPENDENCIES = postgresql-18 libgeos proj libxml2
CUSTOM_POSTGIS_MAKE = $(MAKE1)

CUSTOM_POSTGIS_CONF_OPTS += \
	--with-pgconfig=$(STAGING_DIR)/usr/bin/pg_config \
	--with-geosconfig=$(STAGING_DIR)/usr/bin/geos-config \
	--with-xml2config=$(STAGING_DIR)/usr/bin/xml2-config

ifeq ($(BR2_PACKAGE_JSON_C),y)
CUSTOM_POSTGIS_DEPENDENCIES += json-c
CUSTOM_POSTGIS_CONF_OPTS += --with-json
else
CUSTOM_POSTGIS_CONF_OPTS += --without-json
endif

ifeq ($(BR2_PACKAGE_GDAL),y)
CUSTOM_POSTGIS_DEPENDENCIES += gdal
CUSTOM_POSTGIS_CONF_OPTS += --with-raster --with-gdalconfig=$(STAGING_DIR)/usr/bin/gdal-config
else
CUSTOM_POSTGIS_CONF_OPTS += --without-raster
endif

ifeq ($(BR2_PACKAGE_PCRE),y)
CUSTOM_POSTGIS_DEPENDENCIES += pcre
endif

ifeq ($(BR2_PACKAGE_PROTOBUF_C),y)
CUSTOM_POSTGIS_DEPENDENCIES += protobuf-c
CUSTOM_POSTGIS_CONF_OPTS += --with-protobuf
else
CUSTOM_POSTGIS_CONF_OPTS += --without-protobuf
endif

$(eval $(autotools-package))