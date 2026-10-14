#!/bin/bash
# Runs GNU Go's own regression check against the WASM build, using GNU Go's
# Makefile, regress.sh and regress.awk. regress.awk prints a line only for an
# unexpected result or a crash, so any such line is a failure.
# Usage: test/regress.sh [make-target]   (default: check; "test" runs every batch)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOG="$ROOT/build/regress.log"

make -s -C "$ROOT/build/native/regression" "${1:-check}" \
  GNUGO="node $ROOT/build/gnugo-wasm-cli.js" | tee "$LOG"

if grep -qE "unexpected|Possible crash" "$LOG"; then
  echo "regression check failed"
  exit 1
fi
echo "regression check passed"
