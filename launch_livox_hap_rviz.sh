#!/usr/bin/env bash
set -eEuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source_setup() {
    local setup_file="$1"
    local source_log
    local status

    source_log="$(mktemp)"
    set +e +u
    # shellcheck disable=SC1090
    source "${setup_file}" >"${source_log}" 2>&1
    status=$?
    set -e -u

    if [[ ${status} -ne 0 ]]; then
        cat "${source_log}" >&2
        rm -f "${source_log}"
        return "${status}"
    fi

    grep -vE '^not found: ".*/(autoware_tensorrt_common|autoware_tensorrt_classifier|autoware_tensorrt_plugins|bevdet_vendor)/share/.*/local_setup\.bash"$' "${source_log}" >&2 || true
    rm -f "${source_log}"
}

if [[ -f "${SCRIPT_DIR}/install/setup.bash" ]]; then
    source_setup "${SCRIPT_DIR}/install/setup.bash"
elif [[ -f "/opt/ros/humble/setup.bash" ]]; then
    source_setup "/opt/ros/humble/setup.bash"
fi

if [[ -f "${SCRIPT_DIR}/amaranthus/setup/ubuntu_env.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/amaranthus/setup/ubuntu_env.sh"
fi

if [[ -f "${SCRIPT_DIR}/amaranthus/install/setup.bash" ]]; then
    source_setup "${SCRIPT_DIR}/amaranthus/install/setup.bash"
fi

cd "${SCRIPT_DIR}"

echo "[INFO] Launching livox_ros_driver2 rviz_HAP_launch.py"
echo "[INFO] Extra launch args: ${*:-<none>}"
echo

exec ros2 launch livox_ros_driver2 rviz_HAP_launch.py "$@"
