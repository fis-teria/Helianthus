#!/usr/bin/env bash
set -uo pipefail

cd /home/graneple/Helianthus

mkdir -p Data/logs
log_file="Data/logs/livox_hap_rviz_$(date +%Y%m%d_%H%M%S).log"

echo "[INFO] Logging to ${log_file}"
echo

./launch_livox_hap_rviz.sh "$@" 2>&1 | tee "${log_file}"
status=${PIPESTATUS[0]}

echo
echo "[INFO] livox HAP RViz exited with status ${status}. Press Enter to close."
read -r
exit "${status}"
