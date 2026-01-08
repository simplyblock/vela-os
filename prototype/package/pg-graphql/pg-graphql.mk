PG_GRAPHQL_VERSION = 1.5.11
PG_GRAPHQL_SOURCE = v$(PG_GRAPHQL_VERSION).tar.gz
PG_GRAPHQL_SITE = https://github.com/supabase/pg_graphql/archive/refs/tags
PG_GRAPHQL_LICENSE = PostgreSQL
PG_GRAPHQL_LDFLAGS = $(TARGET_LDFLAGS) $(TARGET_NLS_LIBS)
PG_GRAPHQL_DEPENDENCIES = postgresql

# If you packaged cargo-pgrx as a host tool, add it here:
PG_GRAPHQL_DEPENDENCIES += host-cargo-pgrx

# PostgreSQL pg_config from staging (Buildroot installs a pg_config helper)
PG_GRAPHQL_PG_CONFIG = $(STAGING_DIR)/usr/bin/pg_config

# Derive major version from Buildroot’s postgresql version if available.
# If POSTGRESQL_VERSION is not defined in your tree, just hardcode PG_GRAPHQL_PG_MAJOR = 18 (or 17/16).
PG_GRAPHQL_PG_MAJOR = $(firstword $(subst ., ,$(POSTGRESQL_VERSION)))

# pgrx needs a writable home with config.toml
PG_GRAPHQL_PGRX_HOME = $(@D)/.pgrx-home

# Ensure we only enable ONE pg feature (common pgrx build failure otherwise). :contentReference[oaicite:4]{index=4}
PG_GRAPHQL_FEATURES = pg$(PG_GRAPHQL_PG_MAJOR)

# Let Buildroot’s cargo infra handle cross flags; we just add pgrx env.
PG_GRAPHQL_CARGO_ENV += \
	PGRX_HOME="$(PG_GRAPHQL_PGRX_HOME)" \
	CARGO_NET_OFFLINE=true

define PG_GRAPHQL_BUILD_CMDS
	# 1) Fix: "$PGRX_HOME does not exist"
	mkdir -p "$(PG_GRAPHQL_PGRX_HOME)"

	# 2) Initialize pgrx to register the *staging* pg_config, but don’t run postgres
	# Cross-build guidance from pgrx: init with --no-run and a --pgXX flag. :contentReference[oaicite:5]{index=5}
	(cd $(@D) && \
		$(PG_GRAPHQL_CARGO_ENV) \
		$(HOST_DIR)/bin/cargo pgrx init --no-run --pg$(PG_GRAPHQL_PG_MAJOR) "$(PG_GRAPHQL_PG_CONFIG)")

	# 3) Build the extension as a cdylib for the target
	(cd $(@D) && \
		$(TARGET_MAKE_ENV) \
		$(PG_GRAPHQL_CARGO_ENV) \
		$(HOST_DIR)/bin/cargo build --release \
			--target "$(RUSTC_TARGET_NAME)" \
			--no-default-features --features "$(PG_GRAPHQL_FEATURES)")
endef

define PG_GRAPHQL_INSTALL_TARGET_CMDS
	# Compute target extension dirs from pg_config
	# (control/sql -> sharedir/extension, .so -> pkglibdir). :contentReference[oaicite:6]{index=6}
	PG_SHARE_EXT_DIR="$$("$(PG_GRAPHQL_PG_CONFIG)" --sharedir)/extension"; \
	PG_PKGLIB_DIR="$$("$(PG_GRAPHQL_PG_CONFIG)" --pkglibdir"; \
	$(INSTALL) -d "$(TARGET_DIR)$${PG_SHARE_EXT_DIR}" "$(TARGET_DIR)$${PG_PKGLIB_DIR}"; \
	\
	# Copy SQL + control from the repo
	# (pg_GRAPHQL includes pg_GRAPHQL.control and sql/ in-tree) :contentReference[oaicite:7]{index=7}
	$(INSTALL) -m 0644 $(@D)/pg_GRAPHQL.control "$(TARGET_DIR)$${PG_SHARE_EXT_DIR}/"; \
	if [ -d "$(@D)/sql" ]; then \
		$(INSTALL) -m 0644 $(@D)/sql/*.sql "$(TARGET_DIR)$${PG_SHARE_EXT_DIR}/" 2>/dev/null || true; \
	fi; \
	\
	# Copy the built library.
	# Rust outputs lib<name>.so; Postgres typically loads <extname>.so, so install/rename.
	if [ -f "$(@D)/target/$(RUSTC_TARGET_NAME)/release/libpg_GRAPHQL.so" ]; then \
		$(INSTALL) -m 0755 $(@D)/target/$(RUSTC_TARGET_NAME)/release/libpg_GRAPHQL.so \
			"$(TARGET_DIR)$${PG_PKGLIB_DIR}/pg_GRAPHQL.so"; \
	else \
		echo "ERROR: built library not found"; \
		exit 1; \
	fi
endef

$(eval $(cargo-package))