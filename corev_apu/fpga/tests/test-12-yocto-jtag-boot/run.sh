#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." && pwd)"
DEPLOY_DIR="${YOCTO_DEPLOY_DIR:-/home/carlos/projects/CHAOS/riscv-cores/cva6-yocto/build/tmp-glibc/deploy/images/cv64a6-zcu111}"
GDB="${GDB:-/home/carlos/tools/riscv64/bin/riscv64-unknown-elf-gdb}"
DEBUG_DIR="${TEST12_DEBUG_DIR:-${SCRIPT_DIR}/build/debug/latest}"

FW_JUMP_ELF="${DEPLOY_DIR}/fw_jump.elf"
LINUX_IMAGE="${DEPLOY_DIR}/Image-initramfs-cv64a6-zcu111.bin"
DTB="${DEPLOY_DIR}/cv64a6_zcu111.dtb"

for file in "${FW_JUMP_ELF}" "${LINUX_IMAGE}" "${DTB}"; do
    if [ ! -f "${file}" ]; then
        echo "ERROR: missing Yocto artifact: ${file}" >&2
        exit 1
    fi
done

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

GDB_SCRIPT="${TMP_DIR}/gdb-yocto-boot.gdb"

sed \
    -e "s#\${FW_JUMP_ELF}#${FW_JUMP_ELF}#g" \
    -e "s#\${LINUX_IMAGE}#${LINUX_IMAGE}#g" \
    -e "s#\${DTB}#${DTB}#g" \
    "${SCRIPT_DIR}/gdb-yocto-boot.gdb" > "${GDB_SCRIPT}"

rm -rf "${DEBUG_DIR}"
mkdir -p "${DEBUG_DIR}"
cp "${GDB_SCRIPT}" "${DEBUG_DIR}/gdb-yocto-boot.gdb"

echo "Expected UART evidence:"
echo "  OpenSBI"
echo "  Linux version"
echo "  Yocto userspace init/login messages"
echo
echo "Yocto deploy directory: ${DEPLOY_DIR}"
echo "Bundled Linux Image: ${LINUX_IMAGE}"
echo "DTB: ${DTB}"
echo "Debug artifacts: ${DEBUG_DIR}"
echo

"${GDB}" -q -batch -x "${GDB_SCRIPT}"
