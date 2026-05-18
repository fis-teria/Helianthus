# GUI

Last updated: 2026-05-17

## Current Status

Helianthus の GUI は `amaranthus/gui/` にある PyQt5 / PyQtWebEngine アプリです。車載確認用のメイン画面として、左側に Camera / PointCloud / Map の切り替え表示、右側に vehicle status、Shadow Mode metrics、LiDAR / lane / obstacle view、ログ表示を持っています。

現在の初期表示は Camera view です。Livox HAP の車載レンジが短いケースを踏まえて、カメラを主要な認識表示として扱う方針です。

## Implemented

- `Camera` / `PointCloud` / `Map` の左側ビュー切り替え。
- Camera view は `sensor_msgs/msg/Image` と `CameraInfo` を購読できる。
- E2E overlay image `/shadow/e2e/overlay_image` が流れている間は、通常カメラ画像より優先して表示する。
- PointCloud view は FAST-LIO の `/cloud_registered` を既定入力にした `PointCloud2` 3D 風ビュー。
- PointCloud2 の重い parse は PointCloud view 表示中だけ低Hz worker で行い、Camera view の ROS callback を塞がない。
- PointCloud view は固定レンジ表示で、点群の外接範囲に合わせた自動ズームは行わない。
- Map view は OpenStreetMap / Leaflet ベース。
- 右側 telemetry pane に vehicle status、GPU status、Shadow Mode metrics、周辺 LaserScan / Lane / Obstacle view を表示。
- ROS 2 / Demo のデータソースを項目ごとに切り替え可能。
- ROS 2 topic が実際に流れた項目だけ、該当ボタンを有効化する。
- Dark / Light theme を GUI 上と起動引数で切り替え可能。
- `Full` ボタンは OS フルスクリーンではなく、タイトルバーなしのボーダーレス最大化ウィンドウとして動作する。
- `Esc` / `F11` / `Exit` で通常ウィンドウへ戻る。

## Entry Points

```bash
cd /home/graneple/Helianthus/amaranthus
./gui/run_gui.sh
```

ROS 2 優先で起動する場合:

```bash
cd /home/graneple/Helianthus/amaranthus/gui
uv run main.py --data-source ros2
```

Light theme:

```bash
uv run main.py --theme light
```

## Main ROS 2 Inputs

- Camera image: `/sensing/camera/camera0/image_rect_color`
- Camera overlay image: `/shadow/e2e/overlay_image`
- Camera info: `/sensing/camera/camera0/camera_info`
- PointCloud2: `/cloud_registered`
- Scan: `/scan`
- Lane scan: `/scan`
- Objects JSON: `/detected_objects`
- Vehicle speed: `/vehicle/speed_kmh`
- Vehicle mode: `/vehicle/mode`
- GPS status: `/vehicle/gps_status`

Shadow Mode panel:

- `/shadow/ego/speed`
- `/shadow/ego/yaw_rate`
- `/shadow/ego/curvature`
- `/shadow/virtual/steering_proxy`
- `/shadow/virtual/curvature`
- `/shadow/virtual/warning_score`
- `/shadow/metrics/driver_steering_proxy`
- `/shadow/metrics/steering_delta`
- `/shadow/metrics/curvature_delta`
- `/shadow/metrics/intervention_score`
- `/shadow/metrics/summary`

## Important Files

- `amaranthus/gui/main.py`
- `amaranthus/gui/run_gui.sh`
- `amaranthus/gui/lib/main_window.py`
- `amaranthus/gui/lib/data_sources.py`
- `amaranthus/gui/lib/camera_view.py`
- `amaranthus/gui/lib/pointcloud_view.py`
- `amaranthus/gui/lib/status_panel.py`
- `amaranthus/gui/lib/shadow_panel.py`
- `amaranthus/gui/lib/theme.py`
- `amaranthus/gui/config/ui.yaml`

## Known Gaps

- `shadow_mode_bringup` だけでは、GUI 上段の `/vehicle/speed_kmh`、`/vehicle/mode`、`/vehicle/gps_status` は埋まらない。
- Camera ROS 2 path は compile / import の確認はできているが、実機での frame decoding は実 ROS 2 runtime 上で確認する必要がある。
- GUI の live ROS 2 mode は `numpy` がないと `sensor_msgs` import で落ちるため、`amaranthus/gui/pyproject.toml` と `uv.lock` の依存を維持する。
- LiDAR raw frame で見たい場合は `ROS_POINTCLOUD_TOPIC=/livox/lidar ./gui/run_gui.sh` のように上書きする。
