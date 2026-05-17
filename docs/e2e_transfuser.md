# E2E TransFuser

Last updated: 2026-05-16

## Current Status

`e2e_transfuser` は LEAD / TransFuser V6 系モデルを Shadow Mode 評価へ接続する ADAS package です。実車制御 command は publish せず、camera、optional LiDAR、odometry、route proxy から `/shadow/e2e/*` に仮想 E2E 出力を publish します。

現在の上位 launch は `shadow_mode_e2e_transfuser.launch.py` で、camera + LiDAR bringup、ADAS description、FAST-LIO、Livox lane detection、Shadow Mode、E2E node、E2E metrics、camera overlay をまとめて起動できます。

## Implemented

- E2E runtime mode は `lead_python` が既定。
- `Data/src/lead` と `Data/models/tfv6/tfv6_resnet34` を使う想定。
- CUDA 対応 PyTorch は `Data/venvs/yolo_ros_cuda` を既定で使用。
- 旧 mock path へは `e2e_runtime_mode:=mock` で戻せる。
- `sensor_input_mode` は `auto` / `camera_lidar` / `camera_only`。
- `auto` では LiDAR が途切れた場合に camera-only として待機継続。
- `/shadow/e2e/status` で active sensor mode と missing inputs を確認できる。
- `e2e_path_overlay` が `/shadow/e2e/path` を camera image に重畳。
- YOLO tracking bbox を overlay image に重畳可能。
- `shadow_mode_e2e_metrics` が E2E 出力と ego / virtual control を比較。

## Main Entry Point

```bash
cd /home/graneple/Helianthus/amaranthus
ros2 launch e2e_transfuser shadow_mode_e2e_transfuser.launch.py
```

Mock runtime:

```bash
ros2 launch e2e_transfuser shadow_mode_e2e_transfuser.launch.py \
  e2e_runtime_mode:=mock
```

GPU を使わず YOLO を CPU にする場合:

```bash
ros2 launch e2e_transfuser shadow_mode_e2e_transfuser.launch.py \
  yolo_device:=cpu
```

Camera GUI latency target:

The current GMSL2 capture device advertises `1920x1280 UYVY` only, with `30/20/10fps`
intervals. It does not expose a native `1280x720` mode through V4L2, so the default
bringup throttles camera publishing to `camera_publish_rate:=10.0` and lets the GUI
drop stale camera frames with depth-1 QoS. Use `camera_publish_rate:=30.0` only when
all image consumers can keep up with the full stream.

The V4L2 launcher defaults `use_v4l2_buffer_timestamps:=false` for GUI latency
checks, so image stamps use the system time when the buffer is read. This separates
real GUI/display delay from stale or driver-relative V4L2 buffer timestamps.

For the 10Hz GUI path, the lightweight camera fast path can keep the camera topic as
`camera_output_encoding:=yuv422`. This skips the driver-side full-resolution
`UYVY -> rgb8` conversion; the GUI, E2E runtime, and path overlay now convert
`yuv422` locally when they need RGB. The `fp16_minimal` preset enables this fast path.
The path overlay node is C++ by default and publishes a downscaled display image
with `e2e_overlay_output_max_edge_px:=640`; raise it to `960` or `1280` if visual
detail matters more than GUI update rate.

Desktop shortcut:

```bash
/home/graneple/Desktop/Shadow\ Mode\ E2E\ TransFuser.desktop
```

The desktop launcher goes through `/home/graneple/Helianthus/launch_shadow_mode_e2e_transfuser_terminal.sh`.
It now defaults `E2E_LIGHTWEIGHT_PRESET=fp16_minimal`, which expands to:

```bash
e2e_runtime_mode:=lead_python
e2e_precision_mode:=fp16
e2e_runtime_device:=cuda:0
disable_aux_heads:=true
single_checkpoint:=true
use_yolo:=false
use_livox_lane_detection:=false
camera_output_encoding:=yuv422
```

E2E input preprocessing defaults to the OpenCV CPU path. For comparison runs,
enable the Torch CUDA preprocessing path explicitly:

```bash
E2E_EXTRA_LAUNCH_ARGS='e2e_input_preprocess_backend:=torch_cuda' \
  ./launch_shadow_mode_e2e_transfuser_terminal.sh
```

To override it from a terminal:

```bash
E2E_LIGHTWEIGHT_PRESET=fp32 ./launch_shadow_mode_e2e_transfuser_terminal.sh
E2E_LIGHTWEIGHT_PRESET=none ./launch_shadow_mode_e2e_transfuser_terminal.sh
E2E_LIGHTWEIGHT_PRESET=fp16_minimal ./launch_shadow_mode_e2e_transfuser_terminal.sh
E2E_EXTRA_LAUNCH_ARGS='use_yolo:=false lead_probe_on_startup:=false' \
  ./launch_shadow_mode_e2e_transfuser_terminal.sh
```

`fp16_minimal` keeps the LEAD PyTorch FP16 path but disables YOLO and Livox lane detection
for lower GPU competition during latency checks.

## Default Topics

Inputs:

- Camera image: `/sensing/camera/camera0/image_rect_color`
- Camera info: `/sensing/camera/camera0/camera_info`
- PointCloud2: `/livox/lidar`
- Odometry: `/Odometry`
- Route target: `/shadow/route/target_point`
- YOLO detections: `/yolo/tracking`

Outputs:

- E2E path: `/shadow/e2e/path`
- E2E overlay image: `/shadow/e2e/overlay_image`
- E2E overlay status: `/shadow/e2e/overlay_status`
- E2E metrics:
  - `/shadow/metrics/e2e_steering_delta`
  - `/shadow/metrics/e2e_virtual_steering_delta`
  - `/shadow/metrics/e2e_curvature_delta`
  - `/shadow/metrics/e2e_intervention_score`
  - `/shadow/metrics/e2e_summary`

## Included Components In Default Launch

- `camera_lidar_bringup`
- `adas_description`
- `fast_lio`
- `livox_lane_detection`
- `shadow_mode_bringup`
- `e2e_transfuser`
- `shadow_mode_e2e_metrics`
- `e2e_path_overlay`

## Important Files

- `amaranthus/src/adas/e2e_transfuser/README.md`
- `amaranthus/src/adas/e2e_transfuser/launch/shadow_mode_e2e_transfuser.launch.py`
- `amaranthus/src/adas/e2e_transfuser/config/e2e_transfuser.param.yaml`
- `amaranthus/src/adas/e2e_transfuser/scripts/e2e_transfuser_node.py`
- `amaranthus/src/adas/e2e_path_overlay/`
- `amaranthus/src/shadow_mode/shadow_mode_e2e_metrics/`

## Validation Commands

LEAD dry-run:

```bash
ros2 run e2e_transfuser e2e_transfuser_check_lead.py --dry-run
```

LEAD CUDA probe:

```bash
ros2 run e2e_transfuser e2e_transfuser_probe_lead.py \
  --lead-project-root Data/src/lead \
  --model-path Data/models/tfv6/tfv6_resnet34 \
  --python-site Data/venvs/yolo_ros_cuda/lib/python3.10/site-packages \
  --torch-lib Data/venvs/yolo_ros_cuda/lib/python3.10/site-packages/torch/lib \
  --device cuda:0 \
  --forward
```

## Known Gaps

- Real LEAD / TFv6 weights and runtime environment depend on `Data/` contents on the machine.
- `require_target_point:=true` が既定なので、route target が未入力だと E2E 出力の意味は限定される。
- TensorRT / INT8 は検討導線のみで、calibration と path差分評価が必要。
