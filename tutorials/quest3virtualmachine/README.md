# LEGAL NOTICE

[exploit.c](../../exploit.c) may circumvent certain technological protection measures if used improperly and is provided **strictly** under the narrow DMCA exemption for interoperability/software removal on lawfully owned devices (37 C.F.R. § 201.40(b)(9), effective as of October 28, 2024) [https://www.ecfr.gov/current/title-37/part-201/section-201.40#p-201.40(b)(9)](https://www.ecfr.gov/current/title-37/part-201/section-201.40#p-201.40(b)(9)), as well as in compliance with the Computer Fraud and Abuse Act (18 U.S.C. § 1030) [https://www.justice.gov/jm/jm-9-48000-computer-fraud](https://www.justice.gov/jm/jm-9-48000-computer-fraud)

By viewing, downloading, modifying, or redistributing this repository, you agree to the terms set forth in [DISCLAIMER.md](../../DISCLAIMER.md).

Use of this software is at your own risk, may brick your device, void warranties, and must comply with all applicable laws in your jurisdiction (including outside the US, where no DMCA exemption applies).

This project is for personal, non-commercial research and experimentation only.

# Quest 3 Kernel Build (for QEMU on Linux x86_64 -- or similar)
This tutorial should be followed on a machine as close to Linux as possible for best results. However, there are probably ways for other OS (i.e. WSL for Windows, Homebrew for macOS, etc.)

Note: **The following setup was done on a Linux x86_64 machine running Ubuntu Studio 24.04.**

Additional sidenote: _This tutorial is based of the [README.meta.md](https://github.com/emurray2/oculus-linux-kernel/blob/quest3-buggy-kernel/README.meta.md) found in the [oculus-linux-kernel](https://github.com/emurray2/oculus-linux-kernel) submodule of this repository. To clone in this repository, run `git submodule update --init --recursive`_

## Step 1: Clone android toolchains
```sh
git clone --depth=1 -b android12L-release https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86
git clone --depth=1 -b android12L-release https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9
```

First one is the clang compiler for the host (x86_64). Second is for the ARM cross compiler (aarch64). If machine is already ARM--cross compilation is not necessary.

## Step 2: Install build packages

### Bison (GNU Parser Generator)
`sudo apt install bison`

### Flex (Fast Lexical Analyzer Generator)
`sudo apt install flex`

### Dwarves (DWARF utilities)
`sudo apt install dwarves`

### LZ4 (Fast LZ Compression Algorithm Library)
`sudo apt install lz4`

### General compilers (for BusyBox)
`sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu`

### QEMU (virtual machine)
`sudo apt install qemu && sudo apt install qemu-system-arm`

Tip: **If some packages are not found or the host system is entirely different from that as described above, a Google search or using an alternative package manager such as Homebrew ([https://brew.sh/](https://brew.sh/) - macOS) may suffice**

Additional tip: _If the host system Debian based, missing packages can often be found using `apt search foo` or `apt search bar`. A similar approach may be applied to any package manager. Run the package manager with the `--help` flag or `-h` to see if a search command is possible._

## Step 3: Compile the kernel
Navigate to the [oculus-linux-kernel](https://github.com/emurray2/oculus-linux-kernel) root and run the script below with the following arguments:

1. Path to host compiler - can be set to one of the clang revisions
2. Path to cross compiler
3. Path to source (current directory in this case)
4. Output folder - where the kernel will be built to - create this folder `mkdir q3linuxkernelbuild`

Full command: `./q3_build_script.sh ~/linux-x86/clang-r416183b1 ~/aarch64-linux-android-4.9 . q3linuxkernelbuild`

## Step 4: Build or get a minimal initramfs (root filesystem)
This allows for basic command line utilities to be used and sets up a root filesystem for the kernel. Android and Meta use Toybox: [https://en.wikipedia.org/wiki/Toybox](https://en.wikipedia.org/wiki/Toybox). This tutorial will follow BusyBox ([https://en.wikipedia.org/wiki/BusyBox](https://en.wikipedia.org/wiki/BusyBox)) which is very similar.

### Clone BusyBox
`git clone https://git.busybox.net/busybox -b 1_36_stable`

### Go to the BusyBox source folder
`cd busybox`

### Configure for static binary build
`make menuconfig`

Then navigate to BusyBox Settings -> Build Options and enable: Build BusyBox as a static binary (no shared libs)

### Disable TC (Traffic Control) in config -- (Optional, but may cause build errors on newer Linux kernels--as the header files are missing)

Networking Utilities -> Support traffic control -> Disable (press spacebar until box is empty [])

### Make BusyBox
`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)`

### Install BusyBox
`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install`

### Create basic filesystem and navigate there
This will be where the system mounts and runs initial script.

```sh
mkdir -p ~/my-initramfs
cd ~/my-initramfs
mkdir -p bin sbin etc proc sys dev usr/bin usr/sbin
```

### Copy installed BusyBox files here
`cp -a ~/busybox/_install/* .`

### Create a simple /init script (the first program the kernel runs)

```sh
#!/bin/busybox sh

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Optional: create some basic devices if needed (devtmpfs usually handles)
mknod /dev/console c 5 1
mknod /dev/null c 1 3

echo "Welcome to minimal initramfs!"
echo "BusyBox version $(busybox | head -n1)"

# Drop to a shell (ash is BusyBox's shell)
exec /bin/sh
```

### Make this script executable
`chmod +x init`

### Pack everything into cpio.gz archive
`find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../minimal-initramfs.cpio.gz`

## Step 5: QEMU time! (this will launch a shell with a basic Quest 3 kernel virtual machine)
```sh
qemu-system-aarch64 \
  -M virt \
  -cpu cortex-a57 \
  -smp 4 \
  -m 2G \
  -kernel ~/oculus-linux-kernel/q3linuxkernelbuild/arch/arm64/boot/Image \
  -initrd ~/minimal-initramfs.cpio.gz \
  -append "earlycon=pl011,0x9000000 console=ttyAMA0 root=/dev/ram rdinit=/init nokaslr loglevel=8" \
  -nographic
```