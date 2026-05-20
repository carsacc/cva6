#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUSYBOX_DIR="${BUSYBOX_DIR:-/home/carlos/tools/busybox}"
LINUX_DIR="${LINUX_DIR:-/home/carlos/tools/linux}"
CROSS_COMPILE="${CROSS_COMPILE:-riscv64-linux-gnu-}"
GDB="${RISCV_GDB:-/home/carlos/tools/riscv64/bin/riscv64-unknown-elf-gdb}"
TEST05_DIR="${SCRIPT_DIR}/../test-05-opensbi-smoke"
TEST07_DIR="${SCRIPT_DIR}/../test-07-linux-build"
BUILD_DIR="${SCRIPT_DIR}/build"
BUSYBOX_BUILD_DIR="${BUILD_DIR}/busybox"
LINUX_BUILD_DIR="${BUILD_DIR}/linux"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
ARTIFACTS_DIR="${BUILD_DIR}/artifacts"
CHECK_ONLY=0

if [[ "${1:-}" == "--check-only" ]]; then
  CHECK_ONLY=1
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing command '$1'."
    return 1
  fi
}

need_file() {
  if [[ ! -f "$1" ]]; then
    echo "ERROR: missing $1"
    return 1
  fi
}

check_deps() {
  local missing=0
  for cmd in make dtc cpio bc bison flex rsync "${CROSS_COMPILE}gcc" "${CROSS_COMPILE}strip"; do
    need_cmd "${cmd}" || missing=1
  done

  if [[ ! -f "${BUSYBOX_DIR}/Makefile" ]]; then
    echo "ERROR: BUSYBOX_DIR='${BUSYBOX_DIR}' does not look like a BusyBox source tree."
    echo "Clone with:"
    echo "  git clone --depth 1 --branch 1_36_1 https://git.busybox.net/busybox ${BUSYBOX_DIR}"
    missing=1
  fi

  if [[ ! -f "${LINUX_DIR}/Makefile" ]]; then
    echo "ERROR: LINUX_DIR='${LINUX_DIR}' does not look like a Linux source tree."
    missing=1
  fi

  need_file "${TEST07_DIR}/linux-zcu111.fragment" || missing=1
  need_file "${TEST07_DIR}/zcu111-linux.dts" || missing=1

  if (( missing != 0 )); then
    echo
    echo "Install build dependencies with:"
    echo "  sudo apt update"
    echo "  sudo apt install -y gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu bc bison flex libssl-dev libelf-dev rsync cpio"
    exit 1
  fi

  if [[ ! -x "${GDB}" ]]; then
    echo "ERROR: RISCV_GDB='${GDB}' is not executable."
    exit 1
  fi

  echo "Dependencies found."
}

configure_busybox() {
  mkdir -p "${BUSYBOX_BUILD_DIR}"
  make -C "${BUSYBOX_DIR}" O="${BUSYBOX_BUILD_DIR}" ARCH=riscv CROSS_COMPILE="${CROSS_COMPILE}" defconfig

  set_busybox_bool() {
    local key="CONFIG_$1"
    local config="${BUSYBOX_BUILD_DIR}/.config"
    if grep -q "^${key}=" "${config}"; then
      sed -i "s/^${key}=.*/${key}=y/" "${config}"
    elif grep -q "^# ${key} is not set" "${config}"; then
      sed -i "s/^# ${key} is not set/${key}=y/" "${config}"
    else
      echo "${key}=y" >> "${config}"
    fi
  }

  set_busybox_bool STATIC
  set_busybox_bool ASH
  set_busybox_bool SH_IS_ASH
  set_busybox_bool FEATURE_SH_STANDALONE
  set_busybox_bool CTTYHACK
  set_busybox_bool MOUNT
  set_busybox_bool FEATURE_MOUNT_FLAGS
  set_busybox_bool DMESG
  set_busybox_bool PS
  set_busybox_bool UNAME
  set_busybox_bool CAT
  set_busybox_bool LS
  set_busybox_bool ECHO

  set +o pipefail
  yes "" | make -C "${BUSYBOX_DIR}" O="${BUSYBOX_BUILD_DIR}" ARCH=riscv CROSS_COMPILE="${CROSS_COMPILE}" oldconfig
  local oldconfig_status="${PIPESTATUS[1]}"
  set -o pipefail
  return "${oldconfig_status}"
}

build_busybox_rootfs() {
  rm -rf "${ROOTFS_DIR}"
  mkdir -p "${ROOTFS_DIR}"

  configure_busybox
  make -C "${BUSYBOX_DIR}" O="${BUSYBOX_BUILD_DIR}" ARCH=riscv CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)" busybox
  make -C "${BUSYBOX_DIR}" O="${BUSYBOX_BUILD_DIR}" ARCH=riscv CROSS_COMPILE="${CROSS_COMPILE}" CONFIG_PREFIX="${ROOTFS_DIR}" install

  install -m 0755 "${SCRIPT_DIR}/init" "${ROOTFS_DIR}/init"
  mkdir -p "${ROOTFS_DIR}/dev" "${ROOTFS_DIR}/proc" "${ROOTFS_DIR}/sys" "${ROOTFS_DIR}/tmp" "${ROOTFS_DIR}/run" "${ROOTFS_DIR}/root"

  (
    cd "${ROOTFS_DIR}"
    find . -print0 | cpio --null -ov --format=newc
  ) > "${BUILD_DIR}/initramfs.cpio"
}

build_linux() {
  mkdir -p "${LINUX_BUILD_DIR}/usr" "${ARTIFACTS_DIR}"
  cp "${BUILD_DIR}/initramfs.cpio" "${LINUX_BUILD_DIR}/usr/zcu111-initramfs.cpio"
  cp "${TEST07_DIR}/zcu111-linux.dts" "${LINUX_BUILD_DIR}/zcu111-linux.dts"

  (
    cd "${LINUX_DIR}"
    ARCH=riscv CROSS_COMPILE="${CROSS_COMPILE}" \
      scripts/kconfig/merge_config.sh \
        -n \
        -O "${LINUX_BUILD_DIR}" \
        "${TEST07_DIR}/linux-zcu111.fragment"
  )
  make -C "${LINUX_DIR}" O="${LINUX_BUILD_DIR}" ARCH=riscv CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
  make -C "${LINUX_DIR}" O="${LINUX_BUILD_DIR}" ARCH=riscv CROSS_COMPILE="${CROSS_COMPILE}" -j"$(nproc)" Image vmlinux
  dtc -I dts -O dtb -o "${LINUX_BUILD_DIR}/zcu111-linux.dtb" "${LINUX_BUILD_DIR}/zcu111-linux.dts"

  cp "${LINUX_BUILD_DIR}/arch/riscv/boot/Image" "${ARTIFACTS_DIR}/Image"
  cp "${LINUX_BUILD_DIR}/vmlinux" "${ARTIFACTS_DIR}/vmlinux"
  cp "${LINUX_BUILD_DIR}/zcu111-linux.dtb" "${ARTIFACTS_DIR}/zcu111-linux.dtb"
  cp "${BUILD_DIR}/initramfs.cpio" "${ARTIFACTS_DIR}/initramfs.cpio"
}

boot_linux() {
  make -C "${TEST05_DIR}" all
  cd "${SCRIPT_DIR}"
  exec "${GDB}" -q -batch -x gdb-busybox-boot.gdb
}

check_deps
if (( CHECK_ONLY != 0 )); then
  exit 0
fi

build_busybox_rootfs
build_linux

echo "BusyBox Linux artifacts:"
find "${ARTIFACTS_DIR}" -maxdepth 1 -type f -printf "  %p\n" | sort
echo
echo "Expected UART success line:"
echo "  CVA6 ZCU111 BusyBox initramfs reached"
echo
boot_linux
