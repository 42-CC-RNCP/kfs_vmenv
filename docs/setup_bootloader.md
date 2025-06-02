# Setup bootloader

How the computer boots up.

1. BIOS or UEFI firmware initializes hardware and loads the bootloader.
    - Usually, the bootloader is stored in the Master Boot Record (MBR) or the EFI System Partition (ESP). This first 512 bytes of the disk contain the bootloader code.
2. Bootloader (like GRUB) loads the kernel into memory and executes it.
    a. Scans the partition table to find the kernel image.
    b. Reads the `/boot/grub/grub.cfg` file to determine which kernel to load.
    c. Loads the kernel image (e.g., `vmlinuz-*`) into memory.
    d. Passes control to the kernel, which starts the operating system.
3. Kernel base on the boot parameters to find the root filesystem.
    - The kernel uses the `root=` parameter to locate the root filesystem.
    - It mounts the root filesystem and starts the init process (usually `/sbin/init`).
    - Runs the init process `/etc/inittab` to set up the user space.

## How GRUB works

GRUB (GRand Unified Bootloader) is a bootloader that allows you to select which operating system or kernel to boot. It provides a menu interface and can load multiple operating systems.

### Stages of GRUB

1. **Stage 1**: In the MBR, the first 512 bytes contain the bootloader code. It is responsible for loading Stage Stage 2.
2. **Stage 2**: Located in the `/boot/grub` directory, it provides a more advanced interface and can read configuration files.

### How to configure GRUB

To configure GRUB, you need to edit the `/etc/default/grub` file and then run `update-grub` to apply the changes.

#### Example configuration

```config
# grub.cfg
menuentry "ft_linux" {
    linux /boot/vmlinuz-4.19.295-lyeh root=LABEL=root rw
}
```


## How to install bootloader to the loop device

```sh
# Install GRUB to the loop device
sudo grub-install \
  --target=i386-pc \
  --boot-directory="$BOOTDIR" \
  "$LOOPDEV"
```

- `--target=i386-pc`: Specifies the target architecture (i386 for BIOS systems).
- `--boot-directory="$BOOTDIR"`: Specifies the directory where GRUB will install its files.
- `"$LOOPDEV"`: The loop device where the bootloader will be installed.

## How to test the bootloader

To test the bootloader, you can use a virtual machine or an emulator like QEMU. This allows you to boot from the loop device and verify that the bootloader works correctly.

```sh
# Start QEMU with the loop device
qemu-system-x86_64 \
  -drive file="$LOOPDEV",format=raw \
  -m 512M \
  -nographic
```

- `-drive file="$LOOPDEV",format=raw`: Specifies the loop device as the disk image.
- `-m 512M`: Allocates 512 MB of memory for the virtual machine.
- `-nographic`: Runs QEMU in non-graphical mode, useful for testing bootloaders.

