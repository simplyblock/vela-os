#!/bin/sh

BOARD_DIR="$( dirname "${0}" )"

if grep -q '^BR2_aarch64=y$' "${BR2_CONFIG}"; then
  TARGET_ARCH="arm64"
  KERNEL_IMAGE="Image"
else
  TARGET_ARCH="amd64"
  KERNEL_IMAGE="bzImage"
fi

echo -n "Converting RAW image to QCOW2... "
qemu-img convert -f raw -O qcow2 -o cluster_size=2M,lazy_refcounts=on ${BINARIES_DIR}/rootfs.ext2 ${BINARIES_DIR}/disk.qcow2
rm -rf ${BINARIES_DIR}/rootfs.ext2
echo "done."

if [ -f ${BINARIES_DIR}/${KERNEL_IMAGE} ]; then
  echo "Symlinking Linux kernel image..."
  [ -e ${BINARIES_DIR}/vmlinuz ] && rm ${BINARIES_DIR}/vmlinuz
  ln -s ${KERNEL_IMAGE} ${BINARIES_DIR}/vmlinuz
fi
rm -rf ${BINARIES_DIR}/vmlinux

# A scratch image holding /vmlinuz and /disk.qcow2, which the MDS image copies
# out. Tagged per architecture; publishing combines both into one
# multi-architecture pnfs-guest image the MDS build selects from.
echo "Building guest image pnfs-guest:${TARGET_ARCH}..."
docker build --platform linux/${TARGET_ARCH} --build-arg KERNEL_IMAGE=${KERNEL_IMAGE} \
  -t pnfs-guest:${TARGET_ARCH} -f "${BOARD_DIR}/Dockerfile" "${BINARIES_DIR}"

echo "Build completed."
