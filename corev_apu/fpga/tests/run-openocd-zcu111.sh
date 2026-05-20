#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
JTAG_SPEED_KHZ="${1:-${ZCU111_JTAG_SPEED_KHZ:-100}}"

if [[ ! "${JTAG_SPEED_KHZ}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: JTAG speed must be an integer in kHz."
  echo "Usage: $0 [jtag_speed_khz]"
  echo "Example: $0 1000"
  exit 1
fi

cd "${REPO_ROOT}"
echo "Starting OpenOCD with ZCU111 PMOD JTAG speed ${JTAG_SPEED_KHZ} kHz"
exec openocd -f corev_apu/fpga/zcu111-pmod.cfg -c "adapter speed ${JTAG_SPEED_KHZ}"
