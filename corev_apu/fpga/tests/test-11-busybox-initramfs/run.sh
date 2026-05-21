#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUSYBOX_DIR="${BUSYBOX_DIR:-/home/carlos/tools/busybox}"
LINUX_DIR="${LINUX_DIR:-/home/carlos/tools/linux}"
CROSS_COMPILE="${CROSS_COMPILE:-riscv64-linux-gnu-}"
GDB="${RISCV_GDB:-/home/carlos/tools/riscv64/bin/riscv64-unknown-elf-gdb}"
TEST05_DIR="${SCRIPT_DIR}/../test-05-opensbi-smoke"
TEST07_DIR="${SCRIPT_DIR}/../test-07-linux-build"
COREMARK_DIR="${SCRIPT_DIR}/../../../../verif/tests/custom/coremark"
BUILD_DIR="${SCRIPT_DIR}/build"
BUSYBOX_BUILD_DIR="${BUILD_DIR}/busybox"
COREMARK_BUILD_DIR="${BUILD_DIR}/coremark"
MEMSTRESS_BUILD_DIR="${BUILD_DIR}/memstress"
MMIO_TEST_BUILD_DIR="${BUILD_DIR}/mmio-test"
LINUX_BUILD_DIR="${BUILD_DIR}/linux"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
ARTIFACTS_DIR="${BUILD_DIR}/artifacts"
BUILD_SIGNATURE="${BUILD_DIR}/.build-signature"
COREMARK_ITERATIONS="${COREMARK_ITERATIONS:-2000}"
COREMARK_TOTAL_DATA_SIZE="${COREMARK_TOTAL_DATA_SIZE:-2000}"
COREMARK_CLOCK_HZ="${COREMARK_CLOCK_HZ:-50000000}"
CHECK_ONLY=0
BUILD_ONLY=0
FORCE_REBUILD=0

while (($# > 0)); do
  case "$1" in
    --check-only)
      CHECK_ONLY=1
      ;;
    --build-only)
      BUILD_ONLY=1
      ;;
    --rebuild)
      FORCE_REBUILD=1
      ;;
    *)
      echo "Usage: $0 [--check-only|--build-only] [--rebuild]"
      exit 2
      ;;
  esac
  shift
done

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
  for cmd in make dtc cpio bc bison flex file rsync sha256sum "${CROSS_COMPILE}gcc" "${CROSS_COMPILE}strip"; do
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
  need_file "${COREMARK_DIR}/coremark_main.c" || missing=1
  need_file "${SCRIPT_DIR}/coremark/core_portme.c" || missing=1
  need_file "${SCRIPT_DIR}/coremark/core_portme.h" || missing=1
  need_file "${SCRIPT_DIR}/memstress/memstress.c" || missing=1
  need_file "${SCRIPT_DIR}/mmio-test/mmio-test.c" || missing=1

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

source_tree_id() {
  local path="$1"

  if git -C "${path}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "${path}" rev-parse HEAD
    if ! git -C "${path}" diff --quiet; then
      echo "dirty"
    fi
  else
    stat -c "%n %Y" "${path}/Makefile"
  fi
}

build_inputs() {
  local coremark_files=(
    coremark.h
    coremark_main.c
    core_list_join.c
    core_matrix.c
    core_state.c
    core_util.c
  )

  {
    echo "BUSYBOX_DIR=${BUSYBOX_DIR}"
    echo "BUSYBOX_ID=$(source_tree_id "${BUSYBOX_DIR}")"
    echo "LINUX_DIR=${LINUX_DIR}"
    echo "LINUX_ID=$(source_tree_id "${LINUX_DIR}")"
    echo "CROSS_COMPILE=${CROSS_COMPILE}"
    echo "CC_VERSION=$("${CROSS_COMPILE}gcc" -dumpmachine) $("${CROSS_COMPILE}gcc" -dumpfullversion -dumpversion)"
    echo "COREMARK_ITERATIONS=${COREMARK_ITERATIONS}"
    echo "COREMARK_TOTAL_DATA_SIZE=${COREMARK_TOTAL_DATA_SIZE}"
    echo "COREMARK_CLOCK_HZ=${COREMARK_CLOCK_HZ}"
    sha256sum \
      "${SCRIPT_DIR}/run.sh" \
      "${SCRIPT_DIR}/init" \
      "${SCRIPT_DIR}/check-rootfs.sh" \
      "${SCRIPT_DIR}/gdb-busybox-boot.gdb" \
      "${SCRIPT_DIR}/coremark/core_portme.c" \
      "${SCRIPT_DIR}/coremark/core_portme.h" \
      "${SCRIPT_DIR}/memstress/memstress.c" \
      "${SCRIPT_DIR}/mmio-test/mmio-test.c" \
      "${TEST07_DIR}/linux-zcu111.fragment" \
      "${TEST07_DIR}/zcu111-linux.dts"
    for file in "${coremark_files[@]}"; do
      sha256sum "${COREMARK_DIR}/${file}"
    done
  }
}

current_build_signature() {
  build_inputs | sha256sum | awk '{print $1}'
}

artifacts_ready() {
  [[ -f "${ARTIFACTS_DIR}/Image" ]] || return 1
  [[ -f "${ARTIFACTS_DIR}/vmlinux" ]] || return 1
  [[ -f "${ARTIFACTS_DIR}/zcu111-linux.dtb" ]] || return 1
  [[ -f "${ARTIFACTS_DIR}/initramfs.cpio" ]] || return 1
  [[ -f "${BUILD_SIGNATURE}" ]] || return 1
  "${SCRIPT_DIR}/check-rootfs.sh" >/dev/null || return 1
}

build_is_current() {
  local expected
  local actual

  artifacts_ready || return 1
  expected="$(current_build_signature)"
  actual="$(<"${BUILD_SIGNATURE}")"
  [[ "${expected}" == "${actual}" ]]
}

build_coremark() {
  local coremark_src_dir="${COREMARK_BUILD_DIR}/src"
  local coremark_bin="${COREMARK_BUILD_DIR}/coremark"
  local coremark_files=(
    coremark.h
    coremark_main.c
    core_list_join.c
    core_matrix.c
    core_state.c
    core_util.c
  )

  rm -rf "${COREMARK_BUILD_DIR}"
  mkdir -p "${coremark_src_dir}"

  for file in "${coremark_files[@]}"; do
    cp "${COREMARK_DIR}/${file}" "${coremark_src_dir}/${file}"
  done
  cp "${SCRIPT_DIR}/coremark/core_portme.c" "${coremark_src_dir}/core_portme.c"
  cp "${SCRIPT_DIR}/coremark/core_portme.h" "${coremark_src_dir}/core_portme.h"

  "${CROSS_COMPILE}gcc" \
    -static -O3 -g -Wno-format -march=rv64gc -mabi=lp64d \
    -I"${coremark_src_dir}" \
    -DPERFORMANCE_RUN=1 \
    -DITERATIONS="${COREMARK_ITERATIONS}" \
    -DTOTAL_DATA_SIZE="${COREMARK_TOTAL_DATA_SIZE}" \
    -DCORE_CLOCK_HZ="${COREMARK_CLOCK_HZ}" \
    -DFLAGS_STR="\"-static -O3 -Wno-format -march=rv64gc -mabi=lp64d\"" \
    -o "${coremark_bin}" \
    "${coremark_src_dir}/core_portme.c" \
    "${coremark_src_dir}/coremark_main.c" \
    "${coremark_src_dir}/core_list_join.c" \
    "${coremark_src_dir}/core_matrix.c" \
    "${coremark_src_dir}/core_state.c" \
    "${coremark_src_dir}/core_util.c"

  "${CROSS_COMPILE}strip" "${coremark_bin}"
  install -m 0755 "${coremark_bin}" "${ROOTFS_DIR}/root/coremark"
}

build_memstress() {
  local memstress_bin="${MEMSTRESS_BUILD_DIR}/memstress"

  rm -rf "${MEMSTRESS_BUILD_DIR}"
  mkdir -p "${MEMSTRESS_BUILD_DIR}"

  "${CROSS_COMPILE}gcc" \
    -static -O2 -g -Wall -Wextra -march=rv64gc -mabi=lp64d \
    -o "${memstress_bin}" \
    "${SCRIPT_DIR}/memstress/memstress.c"

  "${CROSS_COMPILE}strip" "${memstress_bin}"
  install -m 0755 "${memstress_bin}" "${ROOTFS_DIR}/root/memstress"
}

build_mmio_test() {
  local mmio_test_bin="${MMIO_TEST_BUILD_DIR}/mmio-test"

  rm -rf "${MMIO_TEST_BUILD_DIR}"
  mkdir -p "${MMIO_TEST_BUILD_DIR}"

  "${CROSS_COMPILE}gcc" \
    -static -O2 -g -Wall -Wextra -march=rv64gc -mabi=lp64d \
    -o "${mmio_test_bin}" \
    "${SCRIPT_DIR}/mmio-test/mmio-test.c"

  "${CROSS_COMPILE}strip" "${mmio_test_bin}"
  install -m 0755 "${mmio_test_bin}" "${ROOTFS_DIR}/root/mmio-test"
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
  build_coremark
  build_memstress
  build_mmio_test
  "${SCRIPT_DIR}/check-rootfs.sh"

  (
    cd "${ROOTFS_DIR}"
    find . -print0 | cpio --null -o --quiet --format=newc
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

build_all() {
  build_busybox_rootfs
  build_linux
  current_build_signature > "${BUILD_SIGNATURE}"
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

if (( FORCE_REBUILD == 0 )) && build_is_current; then
  echo "Build artifacts are current; skipping rebuild."
else
  if (( FORCE_REBUILD != 0 )); then
    echo "Forced rebuild requested."
  else
    echo "Build artifacts are missing or stale; rebuilding."
  fi
  build_all
fi

if (( BUILD_ONLY != 0 )); then
  echo "Build-only mode complete."
  exit 0
fi

echo "BusyBox Linux artifacts:"
find "${ARTIFACTS_DIR}" -maxdepth 1 -type f -printf "  %p\n" | sort
echo
echo "Expected UART success line:"
echo "  CVA6 ZCU111 BusyBox initramfs reached"
echo
boot_linux
