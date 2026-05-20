#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GDB="${RISCV_GDB:-/home/carlos/tools/riscv64/bin/riscv64-unknown-elf-gdb}"
TEST05_DIR="${SCRIPT_DIR}/../test-05-opensbi-smoke"
TEST07_DIR="${SCRIPT_DIR}/../test-07-linux-build"
FW_JUMP="${TEST05_DIR}/build/opensbi/platform/generic/firmware/fw_jump.elf"
LINUX_IMAGE="${TEST07_DIR}/build/artifacts/Image"
LINUX_VMLINUX="${TEST07_DIR}/build/artifacts/vmlinux"
LINUX_DTB="${TEST07_DIR}/build/artifacts/zcu111-linux.dtb"

need_file() {
  if [[ ! -f "$1" ]]; then
    echo "ERROR: missing $1"
    return 1
  fi
}

if [[ ! -x "${GDB}" ]]; then
  echo "ERROR: RISCV_GDB='${GDB}' is not executable."
  exit 1
fi

make -C "${TEST05_DIR}" all

missing=0
need_file "${FW_JUMP}" || missing=1
need_file "${LINUX_IMAGE}" || missing=1
need_file "${LINUX_VMLINUX}" || missing=1
need_file "${LINUX_DTB}" || missing=1

if (( missing != 0 )); then
  echo
  echo "Build the Linux artifacts first:"
  echo "  corev_apu/fpga/tests/test-07-linux-build/run.sh"
  exit 1
fi

echo "Linux early-debug diagnostic:"
echo "  This test is driven by GDB breakpoints; UART may only show the OpenSBI banner."
echo "  Use test-08-linux-boot-smoke for the final UART initramfs validation."
echo

cd "${SCRIPT_DIR}"
exec "${GDB}" -q -batch -x gdb-linux-early-debug.gdb
