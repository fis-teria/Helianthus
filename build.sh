#!/usr/bin/env bash
set -Eeuo pipefail

cleanup_livox_ros_driver2() {
    if [[ "${LIVOX_CREATED_LAUNCH:-0}" == "1" ]]; then
        rm -rf "${LIVOX_DRIVER_DIR}/launch"
    fi
}

on_exit() {
    local status=$?
    cleanup_livox_ros_driver2

    if [[ ${status} -ne 0 ]]; then
        echo
        echo "[ERROR] build.sh failed with exit code ${status}."
        if [[ -t 0 && -t 1 && "${HELIANTHUS_NO_ERROR_PAUSE:-0}" != "1" ]]; then
            read -r -p "Press Enter to close..." _
        fi
    fi

    exit "${status}"
}

trap on_exit EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVOX_DRIVER_DIR="${SCRIPT_DIR}/amaranthus/src/drivers/livox_ros_driver2"

usage() {
    cat <<'USAGE'
Usage: ./build.sh [colcon build args...]

Build the Helianthus workspace from the repository root.

Environment overrides:
  HELIANTHUS_ROS_DISTRO                 ROS distro to source/use (default: humble)
  HELIANTHUS_COLCON_PARALLEL_WORKERS    colcon package workers (default: 1)
  HELIANTHUS_BUILD_JOBS                 compiler jobs (default: memory-safe auto)
  HELIANTHUS_BUILD_LOAD_LIMIT           make load limit (default: compiler jobs)
  HELIANTHUS_CMAKE_BUILD_TYPE           CMake build type (default: Release)
  HELIANTHUS_COLCON_EVENT_HANDLERS      colcon event handlers (default: desktop_notification-)
  HELIANTHUS_BUILD_TESTING              ON/OFF for BUILD_TESTING (default: OFF)
  HELIANTHUS_SKIP_LIVOX_PREPARE         1 to skip livox_ros_driver2 ROS2 preparation
  HELIANTHUS_NO_ERROR_PAUSE             1 to disable interactive error pause

Examples:
  ./build.sh
  ./build.sh --packages-up-to adas_bringup
  HELIANTHUS_COLCON_PARALLEL_WORKERS=2 HELIANTHUS_BUILD_JOBS=4 ./build.sh
USAGE
}

determine_memsafe_jobs() {
    if [[ -n "${HELIANTHUS_BUILD_JOBS:-}" ]]; then
        echo "${HELIANTHUS_BUILD_JOBS}"
        return
    fi

    local cpu_count available_kb available_mb jobs
    cpu_count="$(nproc)"
    available_kb="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || true)"

    if [[ -z "${available_kb}" ]]; then
        echo 1
        return
    fi

    available_mb=$((available_kb / 1024))

    if (( available_mb < 3072 )); then
        jobs=1
    else
        jobs=$(((available_mb - 1024) / 2048))
        if (( jobs < 1 )); then
            jobs=1
        fi
    fi

    if (( jobs > cpu_count )); then
        jobs="${cpu_count}"
    fi

    if (( jobs > 4 )); then
        jobs=4
    fi

    echo "${jobs}"
}

source_ros_environment() {
    local ros_distro="$1"
    local setup_file="/opt/ros/${ros_distro}/setup.bash"

    if [[ -f "${setup_file}" ]]; then
        set +u
        # shellcheck disable=SC1090
        source "${setup_file}"
        set -u
    else
        echo "[WARN] ${setup_file} was not found. Continuing with the current environment."
    fi
}

prepare_livox_ros_driver2() {
    if [[ "${HELIANTHUS_SKIP_LIVOX_PREPARE:-0}" == "1" ]]; then
        echo "[INFO] Skipping livox_ros_driver2 preparation."
        return
    fi

    if [[ ! -d "${LIVOX_DRIVER_DIR}" ]]; then
        echo "[ERROR] livox_ros_driver2 directory not found: ${LIVOX_DRIVER_DIR}" >&2
        exit 1
    fi

    if [[ ! -f "${LIVOX_DRIVER_DIR}/package_ROS2.xml" ]]; then
        echo "[ERROR] package_ROS2.xml not found in ${LIVOX_DRIVER_DIR}" >&2
        exit 1
    fi

    echo "[INFO] Preparing livox_ros_driver2 for ROS 2 build."
    cp -f "${LIVOX_DRIVER_DIR}/package_ROS2.xml" "${LIVOX_DRIVER_DIR}/package.xml"

    # The upstream build script creates this compatibility directory for ROS 2.
    # Keep the same behavior, but remove only the directory this script creates.
    if [[ ! -e "${LIVOX_DRIVER_DIR}/launch" && -d "${LIVOX_DRIVER_DIR}/launch_ROS2" ]]; then
        cp -rf "${LIVOX_DRIVER_DIR}/launch_ROS2" "${LIVOX_DRIVER_DIR}/launch"
        LIVOX_CREATED_LAUNCH=1
    else
        LIVOX_CREATED_LAUNCH=0
    fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

cd "${SCRIPT_DIR}"

ROS_DISTRO="${HELIANTHUS_ROS_DISTRO:-humble}"
COLCON_PARALLEL_WORKERS="${HELIANTHUS_COLCON_PARALLEL_WORKERS:-${AMARANTHUS_COLCON_PARALLEL_WORKERS:-1}}"
BUILD_JOBS="$(determine_memsafe_jobs)"
BUILD_LOAD_LIMIT="${HELIANTHUS_BUILD_LOAD_LIMIT:-${AMARANTHUS_BUILD_LOAD_LIMIT:-${BUILD_JOBS}}}"
CMAKE_BUILD_TYPE="${HELIANTHUS_CMAKE_BUILD_TYPE:-Release}"
COLCON_EVENT_HANDLERS="${HELIANTHUS_COLCON_EVENT_HANDLERS:-desktop_notification-}"
BUILD_TESTING="${HELIANTHUS_BUILD_TESTING:-OFF}"
HUMBLE_ROS=""

if [[ "${ROS_DISTRO}" == "humble" ]]; then
    HUMBLE_ROS="humble"
fi

export MAKEFLAGS="-j${BUILD_JOBS} -l${BUILD_LOAD_LIMIT}"
export CMAKE_BUILD_PARALLEL_LEVEL="${BUILD_JOBS}"

echo "[INFO] Workspace: ${SCRIPT_DIR}"
echo "[INFO] ROS distro: ${ROS_DISTRO}"
echo "[INFO] Build settings: colcon workers=${COLCON_PARALLEL_WORKERS}, jobs=${BUILD_JOBS}, load limit=${BUILD_LOAD_LIMIT}"

source_ros_environment "${ROS_DISTRO}"
if [[ -f "${SCRIPT_DIR}/amaranthus/setup/ubuntu_env.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/amaranthus/setup/ubuntu_env.sh"
fi
if [[ -d /usr/local/cuda ]]; then
    export CUDA_HOME=/usr/local/cuda
    export CUDAToolkit_ROOT=/usr/local/cuda
    export PATH="/usr/local/cuda/bin:${PATH}"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
fi
if [[ -d /opt/acados ]]; then
    export ACADOS_SOURCE_DIR=/opt/acados
    export CMAKE_PREFIX_PATH="/opt/acados:${CMAKE_PREFIX_PATH:-}"
    export LD_LIBRARY_PATH="/opt/acados/lib:${LD_LIBRARY_PATH:-}"
fi
prepare_livox_ros_driver2

colcon build \
    --symlink-install \
    --executor sequential \
    --parallel-workers "${COLCON_PARALLEL_WORKERS}" \
    --event-handlers ${COLCON_EVENT_HANDLERS} \
    "$@" \
    --cmake-args \
    -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
    -DBUILD_TESTING="${BUILD_TESTING}" \
    -DROS_EDITION=ROS2 \
    -DHUMBLE_ROS="${HUMBLE_ROS}"
