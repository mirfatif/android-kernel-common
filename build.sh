#!/bin/bash -ex

# Android Emulator kernel 6.6.57-android15

# Was helpful:
# https://xdaforums.com/t/guide-build-mod-update-kernel-ranchu-goldfish-5-4-5-10-gki-ramdisk-img-modules-rootavd-android-11-r-12-s-avd-google-play-store-api.4220697/

# Kernel source:
# git clone -b android15-6.6 --single-branch --depth=1 https://android.googlesource.com/kernel/common

# Put out-of-tree emulator modules in 'drivers/':
# git clone -b android15-6.6 --single-branch --depth=1 https://android.googlesource.com/kernel/common-modules/virtual-device
# Enable our custom CONFIG_AVD_VIRTUAL_DEVICE.
# Disable duplicate CONFIG_GOLDFISH_PIPE from mainline.

# Build with gcc or better get clang:
# https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/android-15.0.0_r1/clang-r510928.tar.gz
# To check kernel / clang version, run avd with '-show-kernel', or 'file /path/to/kernel-ranchu'
if [ "$LLVM_DIR" ]; then
	DEV_EXPS="AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CC=clang HOSTCC=clang LD=ld.lld DEPMOD=depmod"
	export PATH=$LLVM_DIR/bin:$PATH
fi

DEV_EXPS="$DEV_EXPS O=out"

# Config file with customizations. 'adb pull /proc/config.gz'.
# https://android.googlesource.com/kernel/common-modules/virtual-device/+/refs/heads/android15-6.6/virtual_device.fragment
# https://android.googlesource.com/kernel/common-modules/virtual-device/+/refs/heads/android15-6.6/virtual_device_core.fragment
#
# Loading prebuilt modules with our new kernel won't work, most probably:
# https://source.android.com/docs/core/architecture/kernel/loadable-kernel-modules#module-loading-versioning
# We get: "module xyz: .gnu.linkonce.this_module section size must match the kernel's built struct module size at run time"
# So we need to build all modules found under /lib/modules in ramdisk (Magisk adds that?), /system, /vendor, /odm, /product etc.
#
# Next problem is that emulator's system.img, vendor.img are RO; shared system image, super image, erofs, bla bla.
# And overlaying .ko files from /data does not work b/c that is too late; modules are loaded at early stage e.g. 'on early-init':
# https://source.android.com/docs/core/architecture/kernel/loadable-kernel-modules#module-loading-versioning
# https://cs.android.com/android/platform/superproject/+/android-15.0.0_r1:device/generic/goldfish/init.ranchu.rc;l=27
# https://cs.android.com/android/platform/superproject/+/android-15.0.0_r1:device/generic/goldfish/init.ranchu.rc;l=79
# https://cs.android.com/android/platform/superproject/main/+/main:device/google/cuttlefish/guest/commands/dlkm_loader/dlkm_loader.cpp
#
# So we can put all modules in ramdisk and replace the 'init' with our custom one, which loads all modules and then exec original init.
# But even simpler approach is to build the modules in the kernel binary. So replace all '=m' with '=y'.
# It makes sense also b/c Android loads all modules in one go, not when needed.
[ -f out/.config ]

export ARCH=x86_64

export LOCALVERSION='-mirfatif'

export KBUILD_BUILD_USER='irfan'
export KBUILD_BUILD_HOST='irfan-pc'

rm -f out/.version

#sudo apt install bc bison cpio flex gcc-12 libelf-dev libncurses-dev libssl-dev lz4 make xz-utils

make menuconfig $DEV_EXPS

# Check build.config.gki.x86_64 for required environment
make -j $(nproc --all) $DEV_EXPS

# Not required. We are building virtual-device as in-tree modules.
#make M=drivers/virtual-device $DEV_EXPS

# Not required. We are building all modules within kernel binary.
make modules_install $DEV_EXPS INSTALL_MOD_PATH=$(realpath out/MODULES)
