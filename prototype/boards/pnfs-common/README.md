# pNFS MDS guest

Root filesystem and kernel of the pNFS metadata server guest described in
`design-pnfs-mds-vm.md`. The guest is started by `mds-runner` in the MDS pod and
serves exports assembled by `mds-agent`. Built for `pnfs_qemu_x64_defconfig` and
`pnfs_qemu_arm64_defconfig`.

## Runner contract

What the runner has to provide when it starts QEMU.

### Devices

| Device                 | QEMU                                                                       | Guest                                               |
|------------------------|----------------------------------------------------------------------------|-----------------------------------------------------|
| Root disk (first disk) | `disk.qcow2` from the image as virtio-blk with `readonly=on`              | `/dev/vda`, mounted read-only                       |
| State disk             | the state PVC (raw block) as virtio-blk with `serial=pnfs-state`           | `/dev/disk/by-id/virtio-pnfs-state` → `/var/lib/nfs` |
| Network                | one `virtio-net-pci` on the runner's tap                                   | `eth0`                                              |
| Console                | `virtconsole` on stdio                                                     | `hvc0`                                              |

The state disk is formatted (ext4) on first boot by `x-systemd.makefs` and only
holds the nfsdcld client recovery database. Without it the guest never reaches
`local-fs.target` and the runner's boot deadline restarts the pod.

### Kernel command line

```
root=/dev/vda ro console=hvc0 panic=-1 ip=<guest>::<gateway>:<netmask>:<hostname>:eth0:off
```

arm64 additionally needs `acpi=on`.

- `ip=` is configured by the kernel before init runs. There is no DHCP client
  and no network manager in the guest.
- `<hostname>` must be stable across restarts (the StatefulSet pod name):
  nfsd derives its server owner and scope from it, and NFSv4.1 clients only
  reclaim state after a restart if they did not change.
- `init=` is not needed, the default `/sbin/init` is systemd.

### Architecture specifics

| Architecture | QEMU binary            | Machine / firmware                         | Kernel image |
|--------------|------------------------|--------------------------------------------|--------------|
| amd64        | `qemu-system-x86_64`   | `-machine q35`                             | `bzImage`    |
| arm64        | `qemu-system-aarch64`  | `-machine virt -bios <EDK2 QEMU_EFI.fd>`   | `Image`      |

Both boot the kernel directly with `-kernel`. On arm64 the UEFI firmware is only
there for ACPI and loads the kernel through its EFI stub.

### Shutdown

`system_powerdown` over QMP. systemd-logind handles the ACPI power button and
powers the guest off. `panic=-1` together with QEMU's `-no-reboot` makes a
guest panic end the QEMU process.

## Packaging

The guest is a `scratch` image holding only the files below. `post-image.sh`
builds it locally as `pnfs-guest:<arch>` when the target is the host's own
architecture, and CI publishes every architecture with buildx from
`scripts/Dockerfile.publish`:

| Path          | Content                                           |
|---------------|---------------------------------------------------|
| `/vmlinuz`    | the kernel (`bzImage` on amd64, `Image` on arm64) |
| `/disk.qcow2` | the read-only root filesystem                     |

Published as one multi-architecture `pnfs-guest` image, it is the
`GUEST_IMAGE` of the MDS image (`csi-driver/deploy/image/Dockerfile.mds` in
simplyblock-operator), which copies both to `/mds/kernel/vmlinuz` and
`/mds/disk.qcow2` next to QEMU and `mds-runner`. The arm64 firmware is not part
of the guest: the MDS image installs Alpine's `aavmf` and the runner uses
`/usr/share/AAVMF/QEMU_EFI.fd`.

## Kernel

The guest runs Linux 6.18, the newest long-term series. The pNFS SCSI layout
depends on the NVMe-oF and NFSv4.1 server code, and both change a lot between
releases.

| File                                   | Content                                                              |
|----------------------------------------|----------------------------------------------------------------------|
| `pnfs-qemu-x64/linux.config`           | x86 base config, vela's config carried to 6.18 (savedefconfig)       |
| `pnfs-qemu-arm64/linux.config`         | arm64 base config (savedefconfig)                                    |
| `pnfs-common/linux-pnfs.fragment`      | nfsd, layouts, NVMe-oF/TCP, and the guest contract, on top of either |
| `pnfs-common/patches/linux/linux.hash` | the tarball's sha256                                                 |

The toolchain's kernel headers stay in the 6.12 series (`BR2_KERNEL_HEADERS_6_12`)
rather than following the kernel. The kernel does not build against them, only
userspace does, and headers older than the running kernel are always safe. It
also keeps the prebuilt SDK usable: the archive is named by target and build
host only, so vela and the guest share it, and vela still runs 6.12.

The guest applies none of vela's kernel patches, and does not share its patch
directory, because Buildroot applies every patch in it:

- `0001` to `0004` fix x86 page-table setup during memory hot-add. The runner
  starts QEMU with a fixed `-m` and no hotplug slots, so that code never runs.
- `0005` is Neon's kcompactd debug logging. It prints a line on every kcompactd
  wake, several a second, and the guest console carries each into the MDS pod
  log.

## Guest layout

| Path                            | Kind                  | Content                                                   |
|---------------------------------|-----------------------|-----------------------------------------------------------|
| `/`                             | read-only             | image                                                     |
| `/var`                          | tmpfs                 | populated from `/usr/share/factory/var` on boot           |
| `/var/lib/nfs`                  | state disk            | `nfsdcld/` client recovery database                       |
| `/var/lib/simplyblock/exports`  | tmpfs (under `/var`)  | export mount points                                       |
| `/etc/exports.d`                | → `/run/exports.d`    | export drop-ins, rebuilt by the operator after every boot |
| `/run/nfs`                      | tmpfs                 | nfs-utils state (`etab`, `rpc_pipefs`)                    |

## Services

- `nfs-server.service` with `nfs-mountd`, `nfs-idmapd` and `nfsdcld`. NFSv4.1 and
  4.2 only (`/etc/nfs.conf`). rpcbind, statd and blkmapd are masked.
- `mds-agent.service` starts `/usr/bin/mds-agent` once it is part of the image
  (skipped until then). It may run `EnsureNFSD` itself, which is idempotent
  against the already running server.
- journald forwards to the console, so the runner's pod log carries the
  guest's service logs.
