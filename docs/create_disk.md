# Create and partition virtual disk for kernel

## How to create a virtual disk

`dd` is a command-line utility for Unix and Unix-like operating systems to convert and copy files. It can also be used to create a file of a specific size, which can then be used as a virtual disk image.

```sh
dd if=/dev/zero of=$DISK bs=1M count=0 seek=10240
```

- `if=/dev/zero`: Input file is `/dev/zero`, which produces null bytes.
- `of=kernel.img`: Output file is `kernel.img`, which will be created.
- `bs=1M`: Block size is set to 1 megabyte.
    - This means that each read and write operation will handle 1 megabyte of data at a time.
- `count=0`: This means no blocks are copied from the input file.
- `seek=10240`: This means that the output file will be created with a size of 10,240 megabytes (10 GB), but no actual data is written to it. The file will be sparse, meaning it will not take up physical space on the disk until data is written to it.

## How to partition the virtual disk

### What is loop device?

A loop device is a pseudo-device in Linux that allows a file to be treated as a block device. This means you can use a regular file as if it were a disk drive, enabling you to create filesystems, partitions, and mount them without needing actual hardware.

### Using `losetup` to create a loop device

`losetup` is a command-line utility in Linux that allows you to set up and manage loop devices. A loop device is a pseudo-device that makes a file accessible as a block device, which can be used for mounting filesystems or creating partitions.

The command will output the name of the loop device, which you can use in subsequent commands to create partitions.
```sh
sudo losetup --find --show "$DISK"
```

- `--find`: This option tells `losetup` to find the first available loop device.
- `--show`: This option tells `losetup` to print the name of the loop device that was set up.
- `"$DISK"`: This is the path to the virtual disk file you created earlier (e.g., `kernel.img`).

### Using `parted` to create a partition table

`parted` is a command-line utility for managing disk partitions. It can create, delete, and resize partitions on a disk.

```sh
# 1. Create a new partition table on the loop device
sudo parted "$LOOP_DEVICE" --script mklabel gpt

# 2. Create a partition for the bootloader
sudo parted -s "$LOOPDEV" mkpart primary ext2 1MiB 513MiB      # /boot

# 3. Create a partition for the root filesystem
sudo parted -s "$LOOPDEV" mkpart primary ext4 513MiB 8705MiB   # /

# 4. Create a partition for the swap space
sudo parted -s "$LOOP_DEVICE" mkpart primary linux-swap 8705MiB 100% # swap
```

1. Create a new partition table on the loop device
    - `"$LOOP_DEVICE"`: This is the loop device you created with `losetup`.
    - `--script`: This option tells `parted` to run in script mode, which suppresses interactive prompts.
    - `mklabel gpt`: This command creates a new partition table of type GPT (GUID Partition Table) on the specified loop device.
        - GPT is a modern partitioning scheme that supports larger disks and more partitions than the older MBR (Master Boot Record) scheme.
2. Create a partition for the bootloader
    - `mkpart`: This command creates a new partition.
    - `primary`: This specifies that the partition is a primary partition.
        - Primary partitions are the main partitions on a disk and can contain filesystems.
    - `ext2`: This specifies the filesystem type for the partition.
        - is a traditional Unix filesystem that is simple and efficient, often used for boot partitions.
        - Why not `ext4`? While `ext4` is more modern and widely used, `ext2` is often chosen for boot partitions because it is simpler and has lower overhead, which can be beneficial for bootloader operations.
        - other common filesystem types include `ext4`, `xfs`, and `btrfs`.
            - `ext4`: A more modern and widely used filesystem that supports journaling, larger files, and better performance.
            - `xfs`: A high-performance filesystem that is often used in enterprise environments.
            - `btrfs`: A newer filesystem that supports advanced features like snapshots and checksums.
    - `1MiB 513MiB`: This specifies the start and end points of the partition in megabytes.
        - start point is `1MiB`, which means the partition starts at 1 megabyte from the beginning of the disk.
            - Why 1MiB? This is often done to leave space for the bootloader or other metadata that may need to be placed at the beginning of the disk.
        - end point is `513MiB`, which means the partition ends at 513 megabytes from the beginning of the disk.
            - This size is typically chosen to accommodate the bootloader and its associated files, which usually require around 512 megabytes.
3. Create a partition for the root filesystem
    - starts at `513MiB`, which is the end of the previous partition.
    - ends at `8705MiB`, which is approximately 8.2 gigabytes from the beginning of the disk.
        - This size is typically chosen to provide enough space for the root filesystem, which contains the operating system and user files.
4. Create a partition for the swap space
    - `linux-swap`: This specifies the partition type as Linux swap, which is used for virtual memory.
    - starts at `8705MiB`, which is the end of the previous partition.
    - ends at `100%`, which means the partition will occupy all remaining space on the disk.
        - This allows the swap partition to use all available space after the root filesystem, providing a flexible amount of swap space based on the size of the disk.

### Formatting the partitions

```sh
# Flush the partition table to disk
sudo partprobe "$LOOP_DEVICE"
```

- `partprobe`: This command informs the operating system of partition table changes.

```sh
# Format the partition as ext2, ext4, and swap
BOOT_PART=${LOOPDEV}p1
ROOT_PART=${LOOPDEV}p2
SWAP_PART=${LOOPDEV}p3

sudo mkfs.ext2 "$BOOT_PART"  # Format the boot partition as ext2
sudo mkfs.ext4 "$ROOT_PART"  # Format the root partition as ext4
sudo mkswap "$SWAP_PART"     # Format the swap partition
```
