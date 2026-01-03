#!/bin/sh

BOARD_DIR="$( dirname "${0}" )"

echo -n "Converting RAW image to QCOW2... "
qemu-img convert -f raw -O qcow2 -o cluster_size=2M,lazy_refcounts=on ${BINARIES_DIR}/rootfs.ext2 ${BINARIES_DIR}/disk.qcow2
rm -rf ${BINARIES_DIR}/rootfs.ext2
echo "done."

if [ -f ${BINARIES_DIR}/bzImage ]; then
  echo "Symlinking Linux kernel image..."
  [ -f ${BINARIES_DIR}/vmlinuz ] && rm ${BINARIES_DIR}/vmlinuz
  ln -s bzImage ${BINARIES_DIR}/vmlinuz
fi
rm -rf ${BINARIES_DIR}/vmlinux

echo "Building container image wrapper..."
docker build -t vela-image -f "${BR2_EXTERNAL_VELAOS_PATH}/boards/vela-qemu-x64/scripts/Dockerfile" "${BINARIES_DIR}"

echo "Build completed."
