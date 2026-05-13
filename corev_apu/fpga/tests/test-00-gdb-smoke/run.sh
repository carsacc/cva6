#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GDB="${RISCV_GDB:-/home/carlos/tools/riscv64/bin/riscv64-unknown-elf-gdb}"

exec "${GDB}" -q -batch -x "${SCRIPT_DIR}/gdb-smoke.gdb"
