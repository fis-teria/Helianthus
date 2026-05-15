# Helianthus Docs

Last updated: 2026-05-16

このフォルダは、Helianthus / AMaRanthus 側で現在実装している機能を、あとから追いやすい粒度でまとめる場所です。

## Documents

- [GUI](gui.md): PyQt GUI、Camera / PointCloud / Map 表示、ROS 2 topic 切り替え、ボーダーレス表示。
- [Shadow Mode](shadow_mode.md): ShadowMode の bringup、LiDAR odometry proxy、metrics、replay 評価。
- [E2E TransFuser](e2e_transfuser.md): LEAD / TransFuser V6 系 runtime、E2E shadow output、overlay、E2E metrics。
- [Sensor Bringup](sensor_bringup.md): camera + LiDAR bringup、Tier IV V4L2 camera defaults、YOLO、TF、FAST-LIO。
- [Drivers And Hardware](drivers_and_hardware.md): Livox、V4L2 camera、GMSL2-USB3.0 Conversion Kit、CUDA fallback まわり。

## Repository Shape

- Workspace root: `/home/graneple/Helianthus`
- Main inner repo: `amaranthus/`
- GUI: `amaranthus/gui/`
- ROS 2 packages: `amaranthus/src/`
- Runtime data and models: `amaranthus/Data/`

## Documentation Policy

- 実装済みの内容と、まだ未完の内容を分けて書く。
- 起動コマンド、主要 topic、関連ファイルを必ず残す。
- 実機依存の状態は、いつの観測か分かるように書く。
- 新しい機能を追加したら、このフォルダの該当ページも更新する。
