# kfs_vmenv (ft_linux)

How this project works for futher KFS projects??? TBD

## Pre-requisites

Depend on the subject, we need to build kernel version 4.x. To avoid to have incompatible utils, I decide to use `Debian 10.13` as host system for the virtual machine.

```sh
# For AMD64 architecture (For campus computer)
wget https://cdimage.debian.org/cdimage/archive/10.13.0/amd64/iso-cd/debian-10.13.0-amd64-netinst.iso

# For ARM64 architecture (For my macos)
wget https://cdimage.debian.org/cdimage/archive/10.13.0/arm64/iso-cd/debian-10.13.0-arm64-netinst.iso
```

## Setup Host VM

Add current user to `sudo` group

```sh
sudo usermod -aG sudo $USER
```

Install the required packages and tools

```sh
./scripts/setup_host_env.sh
```

## Setup ft_linux

Once the host VM is ready, we can setup the `ft_linux` project with automated script.

```sh
./bootstrap.sh
```

```
[root]       ─────────────────────────────┐
  ft_linux.sh                             │
   ├ cleanup.sh                           │
   ├ create_disk.sh                       │
   ├ install_rootfs.sh                    │
   ├ build_kernel.sh                      │
   ├ setup_bootloader.sh                  │
   └ init_lfs.sh ───────────┐             │
                            │             │
[lfs]                       ▼             │
  build_lfs_core.sh (toolchain)           │
                            │             │
...(TBD)

```
