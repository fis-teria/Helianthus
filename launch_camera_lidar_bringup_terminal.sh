#!/usr/bin/env bash
set -uo pipefail

cd /home/graneple/Helianthus

mkdir -p Data/logs
log_file="Data/logs/camera_lidar_bringup_$(date +%Y%m%d_%H%M%S).log"

echo "[INFO] Logging to ${log_file}"
echo

./launch_camera_lidar_bringup.sh "$@" 2>&1 | tee "${log_file}"
status=${PIPESTATUS[0]}

echo
echo "[INFO] camera LiDAR bringup exited with status ${status}. Press Enter to close."
read -r
exit "${status}"
