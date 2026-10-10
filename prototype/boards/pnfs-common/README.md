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
nfsd.pnfs_probe_name=<probe file name> nfsd.pnfs_layout_hold=<seconds>
```

arm64 additionally needs `acpi=on`.

- `ip=` is configured by the kernel before init runs. There is no DHCP client
  and no network manager in the guest.
- `<hostname>` must be stable across restarts (the StatefulSet pod name):
  nfsd derives its server owner and scope from it, and NFSv4.1 clients only
  reclaim state after a restart if they did not change.
- `init=` is not needed, the default `/sbin/init` is systemd.
- `nfsd.pnfs_probe_name` and `nfsd.pnfs_layout_hold` turn on the layout hold
  of the guest's nfsd patch (see Kernel). The name must be the one the CSI
  node writes its layout probe under.

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

| File                                     | Content                                                              |
|------------------------------------------|----------------------------------------------------------------------|
| `pnfs-qemu-x64/linux.config`             | x86 base config, vela's config carried to 6.18 (savedefconfig)       |
| `pnfs-qemu-arm64/linux.config`           | arm64 base config (savedefconfig)                                    |
| `pnfs-common/linux-pnfs.fragment`        | nfsd, layouts, NVMe-oF/TCP, and the guest contract, on top of either |
| `pnfs-common/patches/linux/linux.hash`   | the tarball's sha256                                                 |
| `pnfs-common/patches/linux/000*.patch`   | the four nfsd patches below                                          |

The toolchain's kernel headers stay in the 6.12 series (`BR2_KERNEL_HEADERS_6_12`)
rather than following the kernel. The kernel does not build against them, only
userspace does, and headers older than the running kernel are always safe. It
also keeps the prebuilt SDK usable: the archive is named by target and build
host only, so vela and the guest share it, and vela still runs 6.12.

The guest does not share vela's patch directory, because Buildroot applies
every patch in it, and needs none of vela's patches:

- `0001` to `0004` fix x86 page-table setup during memory hot-add. The runner
  starts QEMU with a fixed `-m` and no hotplug slots, so that code never runs.
- `0005` is Neon's kcompactd debug logging. It prints a line on every kcompactd
  wake, several a second, and the guest console carries each into the MDS pod
  log.

It carries four patches of its own. The first,
`0001-nfsd-hold-layouts-until-the-client-has-probed-the-filesystem.patch`: a
pNFS client opens the device a SCSI layout names in the mount namespace of the
task that asked for the layout, and an application pod's `/dev` has no
`disk/by-id`. The CSI node makes the first lookup itself, from the host's
`/dev`, and the client caches the device. A server restart drops that cache,
and if the application asks first, the lookup fails and its I/O goes through
the metadata server from then on. With both parameters set, nfsd answers a
client's layout requests with `NFS4ERR_LAYOUTTRYLATER` until the client has
taken a layout on the probe file of that filesystem, during the grace period
and for `pnfs_layout_hold` seconds after the client's first request past it.
Loopback clients are not held.

The second,
`0002-nfsd-fence-SCSI-registrations-left-by-an-earlier-server-instance.patch`:
a client registers the NVMe reservation key nfsd gives it, and the key carries
the server's boot time. On releasing the device the client's unregister becomes
a Replace with a zero key on NVMe, so its registration outlives the server, and
after a restart the client cannot register its new key: the device is marked
unavailable and its I/O goes through the metadata server. When nfsd reserves the
device for a client, it now preempts every registered key that is neither its
own nor from the current boot. SPDK's target does not implement Preempt and
Abort and answers it with Invalid Field, which also defeated nfsd's fencing of
a client whose recall timed out, so both fall back to a plain Preempt.

The third,
`0003-nfsd-ask-clients-to-retry-a-file-handle-of-an-export-not-back-yet.patch`:
nfsd starts, and grace begins, before the agent has exported every filesystem
again, and a client reclaiming an open on an export not yet back was answered
STALE, which drops the open and fails the application's I/O with EBADF. During
grace an unknown export is now answered NFS4ERR_DELAY, which clients retry.

The fourth,
`0004-nfsd-never-wait-for-a-layout-break-with-an-nfsd-thread-held.patch`: a
write through the metadata server, a size change, and an fallocate make XFS
break the layouts other clients hold on the file, and XFS waits for them with
the nfsd thread held. Clients give layouts back with LAYOUTRETURN, which needs
a free nfsd thread, so once every thread waited in `__break_lease` nfsd served
nothing until each recall timed out and its client was fenced. nfsd now starts
the break without waiting and answers NFS4ERR_DELAY while layouts are out, as
it already does for delegations.

The fifth,
`0005-xfs-optionally-hand-out-pNFS-write-layouts-over-zeroed-written-blocks.patch`:
XFS hands out a write layout over unwritten blocks, and only the client's
LAYOUTCOMMIT converts them to written. The Linux client never resends a commit
a restarted server lost, so data written between a client's last commit and a
server restart reads back as zeros on every other client. With
`xfs.pnfs_zeroed_layouts=1` on the kernel command line, which the runner sets
unless started with `--zeroed-layouts=false`, those blocks are zeroed and
written at allocation, at the cost of a WRITE ZEROES per allocation. The kernel
parameter itself defaults to off, and can be changed at runtime through
`/sys/module/xfs/parameters/pnfs_zeroed_layouts`. The file size still travels
only in LAYOUTCOMMIT.

The sixth,
`0006-nfsd-keep-a-SCSI-layout-s-device-ID-stable-across-a-filesystem-grow.patch`:
`xfs_growfs` increments the filesystem's generation, and nfsd puts it into the
device ID of every layout. A block layout's device address carries the
device's size, so its clients need the new generation. A SCSI device address is
the designator and the client's reservation key, and does not change when the
volume grows. After an expand, every client still looked the device up again,
in the mount namespace of the application that asked for the layout, where it
is not visible: the client stopped using layouts and lost the writes in flight
under the old one. A SCSI layout now carries generation 0, so a grown export
keeps the device every client already has.

## Guest layout

| Path                            | Kind                  | Content                                                   |
|---------------------------------|-----------------------|-----------------------------------------------------------|
| `/`                             | read-only             | image                                                     |
| `/var`                          | tmpfs                 | populated from `/usr/share/factory/var` on boot           |
| `/var/lib/nfs`                  | state disk            | `nfsdcld/` client recovery database                       |
| `/var/lib/simplyblock/exports`  | tmpfs (under `/var`)  | export mount points                                       |
| `/etc/exports.d`                | → `/run/exports.d`    | export drop-ins, rebuilt by the operator after every boot |
| `/run/nfs`                      | tmpfs                 | nfs-utils state (`etab`, `rpc_pipefs`)                    |
| `/root/.ssh`                    | → `/run/root-ssh`     | debug SSH `authorized_keys`, written at boot from fw_cfg  |
| `/run/dropbear`                 | tmpfs                 | debug SSH host key, made fresh at each boot               |

## Services

- `nfs-server.service` with `nfs-mountd`, `nfs-idmapd` and `nfsdcld`. NFSv4.1 and
  4.2 only (`/etc/nfs.conf`). rpcbind, statd and blkmapd are masked.
- `mds-agent.service` starts `/usr/bin/mds-agent` once it is part of the image
  (skipped until then). It may run `EnsureNFSD` itself, which is idempotent
  against the already running server.
- journald forwards to the console, so the runner's pod log carries the
  guest's service logs.
- `debug-ssh.service` runs dropbear on port 22, root by key only (`-s`), and
  only with `simplyblock.debug_ssh=1` on the kernel command line, which the
  runner adds when started with `-debug-ssh`. Buildroot's own `dropbear.service`
  and `dropbear.socket` are masked, so nothing else starts it.
  `debug-ssh-key.service`, under the same condition, copies the runner's public
  key from the QEMU fw_cfg item `opt/io.simplyblock/ssh_authorized_keys` to
  `/run/root-ssh/authorized_keys`. The guest's address is reachable only from
  the runner, so this is a shell for whoever may exec into the runner
  container, and a guest started without the flag has no SSH at all.
