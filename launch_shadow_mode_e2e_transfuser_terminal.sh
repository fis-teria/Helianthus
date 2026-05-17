#!/usr/bin/env bash
set -uo pipefail

cd /home/graneple/Helianthus

mkdir -p Data/logs
log_file="Data/logs/shadow_mode_e2e_transfuser_$(date +%Y%m%d_%H%M%S).log"

: "${E2E_LIGHTWEIGHT_PRESET:=fp16_minimal}"
export E2E_LIGHTWEIGHT_PRESET

echo "[INFO] Logging to ${log_file}"
echo "[INFO] E2E lightweight preset: ${E2E_LIGHTWEIGHT_PRESET}"
echo

./launch_shadow_mode_e2e_transfuser.sh "$@" 2>&1 | tee "${log_file}"
status=${PIPESTATUS[0]}

echo
echo "[INFO] shadow mode E2E TransFuser exited with status ${status}. Press Enter to close."
read -r
exit "${status}"
