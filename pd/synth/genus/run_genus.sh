#!/usr/bin/env bash
# Run the CVA6 cv64a6 GF22FDX area synthesis with Cadence Genus on mazo.
# Usage (from this dir, on mazo):  ./run_genus.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# cva6 repo root = three levels up from pd/synth/genus
export CVA6_REPO_DIR="$(cd "${HERE}/../../.." && pwd)"

# GF22FDX HD stdcell library (LVT 6.01a). TT/0.80V/25C = typical, for area.
LIB_ROOT="${GF22_LIB_ROOT:-/home/users/adcarballo/gf22nhsda/20hd/hdl/lvt/6.01a}"
export GF22_LIB="${GF22_LIB:-${LIB_ROOT}/liberty/logic_synth_lvf/gf22nsdllogl20hdl116a_TT_0P80V_0P00V_0P00V_0P00V_25C.lib.gz}"

# Relaxed target clock by default = minimum-area floor. Tighten (e.g. 2.0 for
# 500 MHz, 1.0 for 1 GHz like the Ariane paper) to see the area/speed tradeoff.
export PERIOD_NS="${PERIOD_NS:-10.0}"

cd "${HERE}"
echo "CVA6_REPO_DIR = ${CVA6_REPO_DIR}"
echo "GF22_LIB      = ${GF22_LIB}"
echo "PERIOD_NS     = ${PERIOD_NS}"
[ -r "${GF22_LIB}" ] || { echo "ERROR: GF22_LIB not readable: ${GF22_LIB}" >&2; exit 1; }

mkdir -p reports
genus -batch -files cva6_genus.tcl -log genus.log
