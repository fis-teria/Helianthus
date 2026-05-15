#!/usr/bin/env bash
set -uo pipefail

cd /home/graneple/Helianthus

mkdir -p Data/logs
log_file="Data/logs/amaranthus_gui_$(date +%Y%m%d_%H%M%S).log"

echo "[INFO] Logging to ${log_file}"
echo

./amaranthus/gui/run_gui.sh "$@" 2>&1 | tee "${log_file}"
status=${PIPESTATUS[0]}

echo
echo "[INFO] AMaRanthus GUI exited with status ${status}."
echo "[INFO] Log saved to ${log_file}"
echo "[INFO] Press Enter to close."
read -r
exit "${status}"
