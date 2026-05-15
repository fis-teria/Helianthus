# Shadow Mode

Last updated: 2026-05-16

## Current Status

Shadow Mode は、実車アクチュエータを制御せず、実走行または replay の入力から ego 推定、仮想制御、評価 metrics を `/shadow/...` に publish する評価パイプラインです。

CAN / OBD から実 driver input を取るのはまだ難しいため、現在は `/Odometry` 由来の車速、曲率、操舵 proxy を使う方針です。FAST-LIO / LiDAR odometry が mainline です。

## Implemented Packages

- `shadow_mode_bringup`: Shadow Mode 全体の起動口。
- `shadow_mode_ego_estimation`: `/Odometry` から ego speed / yaw rate / curvature などを推定。
- `shadow_mode_virtual_control`: LaserScan または PointCloud2 から仮想 path / steering / curvature / warning を生成。
- `shadow_mode_metrics`: Ego proxy と virtual control を比較し、intervention score などを publish。
- `shadow_mode_replay_tools`: rosbag replay、metrics CSV、shadow bag 記録をまとめる補助 CLI。
- `shadow_mode_e2e_metrics`: E2E TransFuser 出力と既存 shadow 出力を比較。

## Entry Points

通常 bringup:

```bash
cd /home/graneple/Helianthus/amaranthus
ros2 launch shadow_mode_bringup shadow_mode_bringup.launch.py
```

Replay-safe bringup:

```bash
ros2 launch shadow_mode_bringup shadow_mode_bringup.launch.py use_adas_bringup:=false
```

PointCloud2 を仮想制御入力にする場合:

```bash
ros2 launch shadow_mode_bringup shadow_mode_bringup.launch.py \
  use_adas_bringup:=false \
  virtual_input_mode:=pointcloud \
  virtual_pointcloud_topic:=/livox/lidar
```

Replay tool:

```bash
ros2 run shadow_mode_replay_tools shadow_mode_replay.py \
  --bag Data/rosbag/sample_drive \
  --scenario sample_drive
```

## Main Inputs

- `/Odometry`: ego estimation の主入力。FAST-LIO などから publish。
- `/livox/lidar`: PointCloud2 入力。
- `/livox/lane_detection/scan`: lane-oriented LaserScan 入力。
- `/scan`: replay / generic scan 入力。

## Main Outputs

Ego:

- `/shadow/ego/path`
- `/shadow/ego/speed`
- `/shadow/ego/yaw_rate`
- `/shadow/ego/curvature`

Virtual control:

- `/shadow/virtual/path`
- `/shadow/virtual/steering_proxy`
- `/shadow/virtual/curvature`
- `/shadow/virtual/warning_score`

Metrics:

- `/shadow/metrics/driver_steering_proxy`
- `/shadow/metrics/steering_delta`
- `/shadow/metrics/curvature_delta`
- `/shadow/metrics/intervention_score`
- `/shadow/metrics/control_delta`
- `/shadow/metrics/summary`

## Evaluation Direction

現状の評価軸は closed-loop driving score ではなく、shadow disagreement / safety margin / intervention-equivalent metrics です。

- Driver proxy vs virtual steering の差分。
- Ego curvature vs virtual curvature の差分。
- Warning score と intervention score。
- 今後追加するなら TTC、clearance、near-miss 系の safety margin。

## Important Files

- `amaranthus/src/shadow_mode/shadow_mode_bringup/launch/shadow_mode_bringup.launch.py`
- `amaranthus/src/shadow_mode/shadow_mode_bringup/README.md`
- `amaranthus/src/shadow_mode/shadow_mode_ego_estimation/`
- `amaranthus/src/shadow_mode/shadow_mode_virtual_control/`
- `amaranthus/src/shadow_mode/shadow_mode_metrics/`
- `amaranthus/src/shadow_mode/shadow_mode_replay_tools/`

## Known Gaps

- Real CAN / OBD driver input は未接続。現在は `/Odometry` proxy。
- Metrics の厳密な time synchronization は今後の改善対象。
- Replay / evaluation は CLI 化されているが、シナリオ管理や比較レポートはまだ薄い。
- Autoware との比較出力は一部導線ありだが、完全な closed-loop 評価ではない。
