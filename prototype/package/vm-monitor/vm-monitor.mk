VM_MONITOR_VERSION = release-proxy-8853
VM_MONITOR_SOURCE = $(VM_MONITOR_VERSION).tar.gz
VM_MONITOR_SITE =  https://github.com/neondatabase/neon/archive/refs/tags
VM_MONITOR_LICENSE = Apache2.0
VM_MONITOR_SUBDIR = libs/vm_monitor

$(eval $(cargo-package))