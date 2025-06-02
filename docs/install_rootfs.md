# Install and configure the rootfs

The root filesystem (rootfs) is the top-level directory structure of a Linux system, containing all the essential files and directories needed for the system to operate.

System folder structure:

- `/sbin`: Contains system binaries that are essential for system administration and maintenance.
- `/bin`: Contains essential command binaries (executables) that are required for the system to boot and run in single-user mode.
- `/dev`: Contains device files that represent hardware devices and virtual devices.
- `/etc`: Contains configuration files for the system and applications.
- `/proc`: Contains information about running processes and system information.
- `/sys`: Contains information about the system's hardware and kernel.

## BusyBox

BusyBox is a software suite that provides several Unix utilities in a single executable file. It is often used in embedded systems and minimal Linux distributions due to its small size and efficiency.

Other solutions like `toybox` or `gosh` can also be used, but BusyBox is the most common choice for embedded systems.

### How to install BusyBox

Use the precompiled binary for your architecture, or compile it from source if you need a specific configuration.

```sh
wget https://busybox.net/downloads/binaries/1.36.0-defconfig-multiarch/busybox-x86_64 -O bin/busybox
chmod +x bin/busybox
```

### How to create command binaries with BusyBox

You can create command binaries using BusyBox by creating symbolic links to the BusyBox binary for each command you want to use. This allows you to use the BusyBox binary as a multi-call binary, where it can execute different commands based on the name of the symlink.

```sh
for cmd in $(./bin/busybox --list); do
    if [[ "$cmd" == "init" || "$cmd" == "reboot" || "$cmd" == "shutdown" || "$cmd" == "poweroff" ]]; then
        ln -s busybox "sbin/$cmd"
    elif [[ "$cmd" == "sh" || "$cmd" == "ash" ]]; then
        ln -s busybox "bin/sh"
    else
        ln -s busybox "bin/$cmd"
    fi
done
```

## Install and configure the init system

The init system is the first process started by the Linux kernel during boot. It is responsible for initializing the system, starting services, and managing processes.

### How to configure

`inittab` is a configuration file for the init system that defines how the system should be initialized and which processes should be started at boot time.

Syntax of `inittab`:

```
# <id>:<runlevel>:<action>:<process>
```

Common actions include:
- `respawn`: Restart the process if it exits.
- `wait`: Wait for the process to finish before continuing.
- `once`: Start the process once and do not respawn it.
- `sysinit`: Run the process during system initialization.
- `ctrlaltde`l: Run the process when Ctrl+Alt+Del is pressed.
- `shutdown`: Run the process during system shutdown.

## Configure the file system table

The file system table (`fstab`) is a configuration file that defines how disk partitions, block devices, and remote filesystems should be mounted into the filesystem.
The `fstab` file is typically located at `/etc/fstab` and contains information about the filesystems, their mount points, and options.

### How to configure

The `fstab` file has the following syntax:

```
# <device> <mount_point> <filesystem_type> <options> <dump> <pass>
```

Common filesystem types include:
- `ext2`: A traditional Unix filesystem that is simple and efficient, often used for boot partitions.
- `ext4`: A more modern and widely used filesystem that supports journaling, larger files, and better performance.
- `xfs`: A high-performance filesystem that is often used in enterprise environment.
- `btrfs`: A newer filesystem that supports advanced features like snapshots and checksums.

```config
# /etc/fstab
LABEL=boot  /boot  ext2  defaults  0  1
LABEL=root  /      ext4  defaults  0  1
LABEL=swap  none   swap  sw        0  0
```

- `LABEL=boot` specifies the boot partition, which is mounted at `/boot` with the `ext2` filesystem type and default options.
- `LABEL=root` specifies the root filesystem, which is mounted at `/` with the `ext4` filesystem type and default options.
- `LABEL=swap` specifies the swap space, which is not mounted to a directory but used for swapping memory.

- `options` can include:
  - `defaults`: Use the default mount options.
  - `ro`: Mount the filesystem as read-only.
  - `rw`: Mount the filesystem as read-write.
  - `noatime`: Do not update access times on files.
  - `nosuid`: Do not allow set-user-identifier or set-group-identifier bits to take effect.
- `dump` is used by the `dump` command to determine which filesystems need to be dumped (backed up). A value of `0` means the filesystem will not be dumped.
- `pass` is used by the `fsck` command to determine the order in which filesystems should be checked at boot time. A value of `0` means the filesystem will not be checked, while a value of `1` indicates that it should be checked first, and a value of `2` indicates that it should be checked after all filesystems with a value of `1`.

## How `BusyBox` works with config files (`inittab`, `fstab`)

1. Kernel boots successfully and call `init` process by executing `/sbin/init` (PID 1).
   - The `init` process is the first user-space process started by the Linux kernel.
   - It is responsible for setting up the system and starting other processes.
   - The `init` process is typically a symbolic link to the BusyBox binary, which provides the functionality of the init system.
2. The `init` process reads the `/etc/inittab` file to determine which processes to start and how to manage them.
3. Keeps monitoring the processes defined in `inittab` and respawns them if they exit unexpectedly.
4. The `mount` command is used to mount filesystems as defined in the `/etc/fstab` file. But need to execute `mount -a` to mount all filesystems defined in `fstab`.

Example of `inittab`:

```config
# /etc/inittab
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t sysfs sys /sys
::sysinit:/bin/mdev -s
::respawn:/sbin/getty 115200 tty1
::ctrlaltdel:/sbin/reboot
```
- `::sysinit:/bin/mount -t proc proc /proc`: This line mounts the `proc` filesystem at `/proc`, which provides information about running processes and system information.
    - `-t proc`: Specifies the type of filesystem to mount, which is `proc` in this case.
    - `proc`: It dynamically created by the kernel without needing a physical disk.
    - `/proc`: The mount point where the `proc` filesystem will be mounted.
- `::sysinit:/bin/mount -t sysfs sys /sys`: This line mounts the `sysfs` filesystem at `/sys`, which provides information about the system's hardware and kernel.
    - `-t sysfs`: Specifies the type of filesystem to mount, which is `sysfs` in this case. Means that the filesystem is used to expose kernel objects and their attributes.
    - `sys`: It dynamically created by the kernel without needing a physical disk.
    - `/sys`: The mount point where the `sysfs` filesystem will be mounted.
- `::sysinit:/bin/mdev -s`: Kernel module loader, this line initializes the device manager `mdev`, which is responsible for managing device nodes in `/dev`. It scans for devices and creates the necessary device nodes.
    - `-s`: This option tells `mdev` to scan for devices and create device nodes in `/dev` at startup.
    - Other device managers like `udev` or `devtmpfs` can also be used, but `mdev` is a lightweight alternative suitable for embedded systems.
- `::respawn:/sbin/getty 115200 tty1`: This line starts a terminal (getty) on the first virtual console (`tty1`) with a baud rate of 115200. The `getty` process is responsible for managing terminal sessions and allowing users to log in.
    - `115200`: The baud rate for the serial console, which determines the speed of communication.
    - `tty1`: The first virtual console, which is typically used for local login.
- `::ctrlaltdel:/sbin/reboot`: This line specifies that when the user presses Ctrl+Alt+Del, the system should reboot.

Example of `fstab`:

```config
# /etc/fstab: static file system information
/dev/root   /       ext4    defaults    0 1
proc        /proc   proc    defaults    0 0
sysfs       /sys    sysfs   defaults    0 0
devtmpfs    /dev    devtmpfs defaults    0 0
```
