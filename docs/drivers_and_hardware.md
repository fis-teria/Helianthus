# Drivers And Hardware

Last updated: 2026-05-16

## Current Status

Helianthus / AMaRanthus では、Livox LiDAR、V4L2 camera、RealSense、FAST-LIO、Nav2 / RTAB-Map 系のサブツリーを含んでいます。現在の車載 ShadowMode / E2E bringup では、主に Livox HAP、Tier IV automotive HDR camera、FAST-LIO、V4L2 camera driver を使います。

## Main Driver Packages

- `amaranthus/src/drivers/livox_ros_driver2`
- `amaranthus/src/drivers/ros2_v4l2_camera`
- `amaranthus/src/drivers/pointcloud_to_laserscan`
- `amaranthus/src/drivers/realsense-ros`
- `amaranthus/src/slam/fast_lio_ros2`
- `amaranthus/src/slam/rtabmap_ros`
- `amaranthus/src/slam/navigation2`

## Livox

Current expected topic:

- `/livox/lidar`

Main launch files:

- `amaranthus/src/drivers/livox_ros_driver2/launch_ROS2/msg_HAP_launch.py`
- `amaranthus/src/drivers/livox_ros_driver2/launch_ROS2/rviz_HAP_launch.py`

E2E / Shadow Mode では `/livox/lidar` を PointCloud2 入力として使います。Livox lane detection は `/livox/lane_detection/scan` や `/livox/lane_detection/objects` を publish します。

## V4L2 Camera

Driver:

- `amaranthus/src/drivers/ros2_v4l2_camera`

Bringup package:

- `amaranthus/src/bringup/camera_lidar_bringup`

Current default profile:

- `tier4_automotive_hdr_camera_c2`

Default camera topic:

- `/sensing/camera/camera0/image_rect_color`

## CUDA Runtime Fallback

`ros2_v4l2_camera` は CUDA 対応で build される場合があります。ただし CUDA が build-time に見つかることと、runtime で GPU が使えることは別です。

方針:

- CUDA device が使える場合は GPU conversion を使う。
- runtime で CUDA device がない場合は CPU conversion へ fallback する。
- CUDA support 自体を削除して回避しない。

## GMSL2-USB3.0 Conversion Kit Notes

過去の実機観測では、`lsusb -t` で `480M`、`/dev/media2` は見えるが usable な `/dev/videoX` stream が出ていない状態がありました。この状態では ROS 2 launch debugging より先に、USB3 physical path を確認します。

確認するもの:

- USB3 port / cable / hub。
- `lsusb -t` で `5000M` 以上として見えているか。
- `v4l2-ctl --list-devices` で usable な `/dev/videoX` があるか。
- `v4l2-ctl --device=/dev/videoX --list-formats-ext` が通るか。

## Important Files

- `amaranthus/src/drivers/ros2_v4l2_camera/launch/v4l2_camera.launch.py`
- `amaranthus/src/bringup/camera_lidar_bringup/config/v4l2_camera.param.yaml`
- `amaranthus/src/bringup/camera_lidar_bringup/config/tier4_c2_v4l2_camera.param.yaml`
- `amaranthus/src/bringup/camera_lidar_bringup/config/tier4_c1_v4l2_camera.param.yaml`
- `amaranthus/src/drivers/livox_ros_driver2/`
- `amaranthus/src/slam/fast_lio_ros2/`

## Known Gaps

- Camera hardware availability and exact device node are machine-state dependent.
- USB transport health must be confirmed before treating ROS 2 camera launch failures as software issues.
- Camera calibration and long-range front recognition tuning are still separate tasks from driver bringup.
