# Sensor Bringup

Last updated: 2026-05-16

## Current Status

Camera + LiDAR の sensor-only bringup は `camera_lidar_bringup` に分離されています。E2E launch からもこの bringup を呼び出すため、上位 launch に driver logic を直接増やしすぎない構成です。

現在の camera default は Tier IV automotive HDR camera C2 profile です。LiDAR は Livox HAP launch を使う想定です。

## Implemented

- V4L2 camera 起動。
- Livox driver 起動。
- Livox RViz 起動オプション。
- YOLO node / tracking node / debug node 起動オプション。
- Tier IV C2 / C1 camera parameter YAML。
- camera rate diagnostics parameter。
- E2E launch から sensor bringup を既定で起動。
- ADAS description による `base_link` / `livox_frame` / `camera0` TF publish。
- E2E launch から FAST-LIO を単独起動可能。

## Entry Points

Sensor-only:

```bash
cd /home/graneple/Helianthus/amaranthus
ros2 launch camera_lidar_bringup camera_lidar_bringup.launch.py
```

E2E full path:

```bash
ros2 launch e2e_transfuser shadow_mode_e2e_transfuser.launch.py
```

LiDAR RViz も起動:

```bash
ros2 launch camera_lidar_bringup camera_lidar_bringup.launch.py use_livox_rviz:=true
```

## Default Camera Settings

- Namespace: `/sensing/camera`
- Camera name: `camera0`
- Image topic: `image_rect_color`
- Full image topic: `/sensing/camera/camera0/image_rect_color`
- Hardware ID: `tier4_automotive_hdr_camera_c2`
- Parameter file: `camera_lidar_bringup/config/tier4_c2_v4l2_camera.param.yaml`
- Sensor data QoS: enabled

## Default LiDAR Settings

- PointCloud2 topic: `/livox/lidar`
- Livox launch without RViz: `livox_ros_driver2/launch_ROS2/msg_HAP_launch.py`
- Livox launch with RViz: `livox_ros_driver2/launch_ROS2/rviz_HAP_launch.py`

## TF Frames

Published by `adas_description`:

- `base_link`
- `livox_frame`
- `camera0`

Current URDF placements:

- `livox_frame`: `xyz="0.0 -0.8 0.8"` from `base_link`
- `camera0`: `xyz="1.2 0.1 1.35"` from `base_link`

Coordinate convention follows REP-103:

- x: forward
- y: left
- z: up

## FAST-LIO

E2E launch starts FAST-LIO directly when `use_fast_lio:=true`.

Defaults:

- Package: `fast_lio`
- Launch: `mapping.launch.py`
- Config file: `mid360.yaml`
- Odometry output: `/Odometry`

## Important Files

- `amaranthus/src/bringup/camera_lidar_bringup/launch/camera_lidar_bringup.launch.py`
- `amaranthus/src/bringup/camera_lidar_bringup/config/tier4_c2_v4l2_camera.param.yaml`
- `amaranthus/src/bringup/camera_lidar_bringup/config/tier4_c1_v4l2_camera.param.yaml`
- `amaranthus/src/bringup/camera_lidar_bringup/config/rate_diagnostics.param.yaml`
- `amaranthus/src/bringup/adas_description/urdf/adas_livox.urdf`
- `amaranthus/src/slam/fast_lio_ros2/config/mid360.yaml`

## Known Gaps

- Camera device path / hardware transport は実機接続状態に依存する。
- GMSL2-USB3.0 Conversion Kit が USB2 480M として見えている場合は、ROS 2 launch より先にUSB3物理経路の確認が必要。
- `camera_info_url` は既定で空なので、必要なら実カメラ calibration file を明示する。
