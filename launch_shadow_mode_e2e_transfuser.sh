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

cd "${SCRIPT_DIR}/amaranthus"

append_launch_arg_if_missing() {
    local key="$1"
    local value="$2"
    shift 2
    local arg

    for arg in "$@"; do
        if [[ "${arg}" == "${key}:="* ]]; then
            return 0
        fi
    done

    LIGHTWEIGHT_ARGS+=("${key}:=${value}")
}

LIGHTWEIGHT_ARGS=()
LIGHTWEIGHT_PRESET="${E2E_LIGHTWEIGHT_PRESET:-}"

case "${LIGHTWEIGHT_PRESET}" in
    ""|"none"|"off")
        ;;
    "fp32"|"pytorch_fp32"|"baseline")
        append_launch_arg_if_missing "e2e_runtime_mode" "lead_python" "$@"
        append_launch_arg_if_missing "e2e_precision_mode" "fp32" "$@"
        append_launch_arg_if_missing "e2e_runtime_device" "cuda:0" "$@"
        append_launch_arg_if_missing "disable_aux_heads" "true" "$@"
        append_launch_arg_if_missing "single_checkpoint" "true" "$@"
        ;;
    "fp16"|"pytorch_fp16")
        append_launch_arg_if_missing "e2e_runtime_mode" "lead_python" "$@"
        append_launch_arg_if_missing "e2e_precision_mode" "fp16" "$@"
        append_launch_arg_if_missing "e2e_runtime_device" "cuda:0" "$@"
        append_launch_arg_if_missing "disable_aux_heads" "true" "$@"
        append_launch_arg_if_missing "single_checkpoint" "true" "$@"
        ;;
    "fp16_minimal"|"pytorch_fp16_minimal"|"lead_only_fp16")
        append_launch_arg_if_missing "e2e_runtime_mode" "lead_python" "$@"
        append_launch_arg_if_missing "e2e_precision_mode" "fp16" "$@"
        append_launch_arg_if_missing "e2e_runtime_device" "cuda:0" "$@"
        append_launch_arg_if_missing "disable_aux_heads" "true" "$@"
        append_launch_arg_if_missing "single_checkpoint" "true" "$@"
        append_launch_arg_if_missing "use_yolo" "false" "$@"
        append_launch_arg_if_missing "use_livox_lane_detection" "false" "$@"
        append_launch_arg_if_missing "camera_output_encoding" "yuv422" "$@"
        ;;
    "mock")
        append_launch_arg_if_missing "e2e_runtime_mode" "mock" "$@"
        ;;
    "tensorrt_fp16")
        append_launch_arg_if_missing "e2e_runtime_mode" "tensorrt" "$@"
        append_launch_arg_if_missing "e2e_precision_mode" "fp16" "$@"
        append_launch_arg_if_missing "disable_aux_heads" "true" "$@"
        append_launch_arg_if_missing "single_checkpoint" "true" "$@"
        ;;
    *)
        echo "[ERROR] Unknown E2E_LIGHTWEIGHT_PRESET=${LIGHTWEIGHT_PRESET}" >&2
        echo "[ERROR] Use one of: none, fp32, fp16, fp16_minimal, mock, tensorrt_fp16" >&2
        exit 2
        ;;
esac

if [[ -n "${E2E_EXTRA_LAUNCH_ARGS:-}" ]]; then
    # Extra args are intended for simple ROS launch assignments, e.g.
    # E2E_EXTRA_LAUNCH_ARGS='use_yolo:=false lead_probe_on_startup:=false'
    read -r -a EXTRA_ARGS <<<"${E2E_EXTRA_LAUNCH_ARGS}"
else
    EXTRA_ARGS=()
fi

echo "[INFO] Launching shadow_mode_e2e_transfuser.launch.py"
echo "[INFO] Lightweight preset: ${LIGHTWEIGHT_PRESET:-none}"
echo "[INFO] Preset launch args: ${LIGHTWEIGHT_ARGS[*]:-<none>}"
echo "[INFO] Env extra launch args: ${EXTRA_ARGS[*]:-<none>}"
echo "[INFO] CLI launch args: ${*:-<none>}"
echo

exec ros2 launch e2e_transfuser shadow_mode_e2e_transfuser.launch.py \
    "${LIGHTWEIGHT_ARGS[@]}" \
    "${EXTRA_ARGS[@]}" \
    "$@"
