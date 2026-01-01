#!/bin/sh
BOARD_DIR="$( dirname "${0}" )"

# Write version information
cat > ${TARGET_DIR}/etc/velaos << EOF
name=Vela OS
version=${VELAOS_VERSION}
build=${VELAOS_BUILD}
EOF
