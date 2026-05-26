#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_DIR="${ROOTFS_DIR:-${SCRIPT_DIR}/build/rootfs}"
COREMARK="${ROOTFS_DIR}/root/coremark"
DHRYSTONE="${ROOTFS_DIR}/root/dhrystone"
REFERENCE_RUNNER="${ROOTFS_DIR}/root/run-reference-benchmarks"
MEMSTRESS="${ROOTFS_DIR}/root/memstress"
MMIO_TEST="${ROOTFS_DIR}/root/mmio-test"
IRQ_TEST="${ROOTFS_DIR}/root/irq-test"
AES_GCM_TEST="${ROOTFS_DIR}/root/aes-gcm-test"

check_static_riscv_binary() {
  local binary="$1"
  local label="$2"

  if [[ ! -x "${binary}" ]]; then
    echo "FAIL: missing executable ${binary}"
    exit 1
  fi

  if ! file "${binary}" | grep -q "RISC-V"; then
    echo "FAIL: ${binary} is not a RISC-V executable"
    file "${binary}"
    exit 1
  fi

  if ! file "${binary}" | grep -q "statically linked"; then
    echo "FAIL: ${binary} is not statically linked"
    file "${binary}"
    exit 1
  fi

  echo "PASS: rootfs contains static RISC-V ${label} at ${binary#${ROOTFS_DIR}}"
}

check_static_riscv_binary "${COREMARK}" "CoreMark"
check_static_riscv_binary "${DHRYSTONE}" "Dhrystone"

if [[ ! -x "${REFERENCE_RUNNER}" ]]; then
  echo "FAIL: missing executable ${REFERENCE_RUNNER}"
  exit 1
fi

if ! grep -Fq "/root/coremark 0x0 0x0 0x66 0 7 1 2000" "${REFERENCE_RUNNER}"; then
  echo "FAIL: ${REFERENCE_RUNNER} does not run the customer CoreMark argument set"
  exit 1
fi

echo "PASS: rootfs contains reference benchmark runner at ${REFERENCE_RUNNER#${ROOTFS_DIR}}"

check_static_riscv_binary "${MEMSTRESS}" "memstress"
check_static_riscv_binary "${MMIO_TEST}" "MMIO test"
check_static_riscv_binary "${IRQ_TEST}" "IRQ test"
check_static_riscv_binary "${AES_GCM_TEST}" "AES-GCM KAT test"
