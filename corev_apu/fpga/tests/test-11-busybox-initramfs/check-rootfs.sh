#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_DIR="${ROOTFS_DIR:-${SCRIPT_DIR}/build/rootfs}"
COREMARK="${ROOTFS_DIR}/root/coremark"

if [[ ! -x "${COREMARK}" ]]; then
  echo "FAIL: missing executable ${COREMARK}"
  exit 1
fi

if ! file "${COREMARK}" | grep -q "RISC-V"; then
  echo "FAIL: ${COREMARK} is not a RISC-V executable"
  file "${COREMARK}"
  exit 1
fi

if ! file "${COREMARK}" | grep -q "statically linked"; then
  echo "FAIL: ${COREMARK} is not statically linked"
  file "${COREMARK}"
  exit 1
fi

echo "PASS: rootfs contains static RISC-V CoreMark at /root/coremark"
