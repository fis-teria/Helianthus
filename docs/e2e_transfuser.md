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
