#!/bin/sh
BOARD_DIR="$( dirname "${0}" )"

# Write version information
cat > ${TARGET_DIR}/etc/velaos << EOF
name=Vela OS (pNFS MDS)
version=${VELAOS_VERSION}
build=${VELAOS_BUILD}
EOF

makeSymlink() {
  source="$1"
  dest="$2"

  if [ -h "${dest}" ] || [ -e "${dest}" ]; then
    rm -rf "${dest}"
  fi
  ln -s "${source}" "${dest}"
}

UNITDIR="${TARGET_DIR}/usr/lib/systemd/system"
mkdir -p "${TARGET_DIR}/etc/systemd/system" "${TARGET_DIR}/etc/systemd/network" \
         "${UNITDIR}/multi-user.target.wants"

# NFSv4.1+ only: rpcbind is pulled in by nfs-utils but must not run. statd and
# blkmapd serve NFSv3 locking and the client side respectively.
echo "Configuring NFS server..."
for unit in rpcbind.service rpcbind.socket nfs-blkmap.service rpc-statd.service \
            rpc-statd-notify.service; do
  makeSymlink "/dev/null" "${TARGET_DIR}/etc/systemd/system/${unit}"
done
makeSymlink "../nfs-server.service" "${UNITDIR}/multi-user.target.wants/nfs-server.service"
makeSymlink "../mds-agent.service" "${UNITDIR}/multi-user.target.wants/mds-agent.service"

# The root filesystem is read-only, the assembler writes its exports here.
makeSymlink "/run/exports.d" "${TARGET_DIR}/etc/exports.d"

# The state disk (QEMU serial "pnfs-state") holds the nfsdcld client recovery
# database. systemd formats it on first boot and mounts it before nfsd starts.
# A missing state disk fails local-fs.target, the guest never turns healthy and
# the runner's boot deadline restarts the pod.
echo "Configuring state disk..."
sed -i '\#[[:space:]]/var/lib/nfs[[:space:]]#d' "${TARGET_DIR}/etc/fstab"
echo "/dev/disk/by-id/virtio-pnfs-state /var/lib/nfs ext4 defaults,noatime,x-systemd.makefs,x-systemd.device-timeout=30s 0 2" \
  >> "${TARGET_DIR}/etc/fstab"

# The address comes from the kernel command line (ip=...:eth0:off) and is
# configured before udev runs, keep kernel interface names so it stays on eth0.
makeSymlink "/dev/null" "${TARGET_DIR}/etc/systemd/network/99-default.link"
