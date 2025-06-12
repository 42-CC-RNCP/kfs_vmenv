# Cross Toolchain

## What is a Cross Toolchain? Why do we need it?

When we build our own Linux distribution, we cannot use the host system's toolchain to compile the userland programs for the target architecture. Because the host system's toolchain is designed to compile programs for the host architecture, not the target architecture. Therefore, we need a cross toolchain that can compile programs for the target architecture.
    - Target system and host system's libraries and headers are different.
    - The target system should be clean and not depend on the host system's libraries and headers.

So the cross toolchain is a set of tools that allows us to compile programs for a different architecture than the one we are currently using. It includes a cross compiler, linker, and other tools that are necessary for building programs for the target architecture.
    - It runs on the host system but generates code for the target system.

## Prepare the temporary directory for the cross toolchain (on the host system)

Isolated from the host system, the cross toolchain will be built in a temporary directory. This directory will contain all the necessary tools and libraries to build the userland programs for the target architecture.

In this excercise, I already created disk and partition for `boot` and `rootfs` directories. So we will create the temporary directory `tools` in the `rootfs` directory.

And then we need to create LFS user and group to build the cross toolchain. This is a good practice to avoid running the build process as the root user, which can lead to security issues and potential damage to the system.

```sh
sudo groupadd lfs
id -u lfs &>/dev/null || sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
sudo chown -v lfs $LFS/{,sources,tools}
sudo chmod -v a+wt $LFS/{,sources,tools}
```

### Download the cross toolchain sources

The cross toolchain sources are available on the LFS website. You can download them using the following commands:

```sh
wget -nc https://www.linuxfromscratch.org/lfs/downloads/stable/wget-list
wget -nc https://www.linuxfromscratch.org/lfs/downloads/stable/md5sums

wget --input-file=wget-list --continue -P $LFS/sources
md5sum --check md5sums --status
```

## Build the cross toolchain

The cross toolchain will be built in the `tools` directory. The build process will take some time.
