#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="${LINUX_DIR:-/home/carlos/tools/linux}"
CROSS_COMPILE="${CROSS_COMPILE:-riscv64-linux-gnu-}"
BUILD_DIR="${SCRIPT_DIR}/build"
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

check_deps() {
  local missing=0
  for cmd in make dtc cpio bc bison flex rsync "${CROSS_COMPILE}gcc" "${CROSS_COMPILE}strip"; do
    need_cmd "${cmd}" || missing=1
  done

  if [[ ! -f "${LINUX_DIR}/Makefile" ]]; then
    echo "ERROR: LINUX_DIR='${LINUX_DIR}' does not look like a Linux source tree."
    echo "Clone with:"
    echo "  git clone --depth 1 --branch linux-6.6.y https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git ${LINUX_DIR}"
    missing=1
  fi

  if (( missing != 0 )); then
    echo
    echo "Install build dependencies with:"
    echo "  sudo apt update"
    echo "  sudo apt install -y gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu bc bison flex libssl-dev libelf-dev rsync cpio"
    exit 1
  fi

  echo "Dependencies found."
}

build_initramfs() {
  rm -rf "${ROOTFS_DIR}"
  mkdir -p "${ROOTFS_DIR}" "${BUILD_DIR}"

  "${CROSS_COMPILE}gcc" -Os -static -Wall -Wextra \
    -o "${ROOTFS_DIR}/init" "${SCRIPT_DIR}/init.c"
  "${CROSS_COMPILE}strip" "${ROOTFS_DIR}/init"
  chmod 0755 "${ROOTFS_DIR}/init"

  (
    cd "${ROOTFS_DIR}"
    find . -print0 | cpio --null -ov --format=newc
  ) > "${BUILD_DIR}/initramfs.cpio"
}

build_linux() {
  mkdir -p "${LINUX_BUILD_DIR}" "${ARTIFACTS_DIR}"
  mkdir -p "${LINUX_BUILD_DIR}/usr"
  cp "${BUILD_DIR}/initramfs.cpio" "${LINUX_BUILD_DIR}/usr/zcu111-initramfs.cpio"
  cp "${SCRIPT_DIR}/zcu111-linux.dts" "${LINUX_BUILD_DIR}/zcu111-linux.dts"

  (
    cd "${LINUX_DIR}"
    ARCH=riscv CROSS_COMPILE="${CROSS_COMPILE}" \
      scripts/kconfig/merge_config.sh \
        -n \
        -O "${LINUX_BUILD_DIR}" \
        "${SCRIPT_DIR}/linux-zcu111.fragment"
  )
  make -C "${LINUX_DIR}" O="${LINUX_BUILD_DIR}" ARCH=riscv CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
  make -C "${LINUX_DIR}" O="${LINUX_BUILD_DIR}" ARCH=riscv CROSS_COMPILE="${CROSS_COMPILE}" \
    -j"$(nproc)" Image vmlinux
  dtc -I dts -O dtb -o "${LINUX_BUILD_DIR}/zcu111-linux.dtb" "${LINUX_BUILD_DIR}/zcu111-linux.dts"

  cp "${LINUX_BUILD_DIR}/arch/riscv/boot/Image" "${ARTIFACTS_DIR}/Image"
  cp "${LINUX_BUILD_DIR}/vmlinux" "${ARTIFACTS_DIR}/vmlinux"
  cp "${LINUX_BUILD_DIR}/zcu111-linux.dtb" "${ARTIFACTS_DIR}/zcu111-linux.dtb"
  cp "${BUILD_DIR}/initramfs.cpio" "${ARTIFACTS_DIR}/initramfs.cpio"
}

check_deps
if (( CHECK_ONLY != 0 )); then
  exit 0
fi

build_initramfs
build_linux

echo "Linux artifacts:"
find "${ARTIFACTS_DIR}" -maxdepth 1 -type f -printf "  %p\n" | sort
