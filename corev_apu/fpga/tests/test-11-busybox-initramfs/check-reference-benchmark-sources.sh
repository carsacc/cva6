#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REFERENCE_DIR="${SCRIPT_DIR}/reference-benchmarks"
CHECKSUMS="${REFERENCE_DIR}/ORIGIN.sha256"

if [[ ! -f "${CHECKSUMS}" ]]; then
  echo "FAIL: missing reference benchmark checksum manifest ${CHECKSUMS}"
  exit 1
fi

(
  cd "${REFERENCE_DIR}"
  sha256sum -c ORIGIN.sha256
)

echo "PASS: reference benchmark snapshot matches customer baseline"
