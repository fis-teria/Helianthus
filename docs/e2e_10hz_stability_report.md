# E2E 10Hz Stability Report

Date: 2026-05-17

Goal:

- Make the ShadowMode E2E camera-to-GUI path stable at 10Hz.
- Keep each change measurable and reversible.

Reporting:

- Short progress notes are posted in the active Codex chat.
- This file keeps the running report for later review.

## Working Hypothesis

The LEAD/E2E model path is fast enough for 10Hz. The likely bottlenecks are camera
publication, ROS image delivery, overlay generation, GUI subscription/paint timing,
and GPU contention from optional perception nodes.

## Log

### Initial Setup

- Created this live report file.
- Next step: inspect current running ROS processes and measure topic rates/latency.

### Git Baseline

- Saved the pre-tuning state before starting the improvement loop.
- Helianthus: `ffce248 Save pre-10Hz tuning baseline`
- AMaRanthus: `e9f4537 Save E2E 10Hz baseline changes`
- ros2_v4l2_camera: `8f31ede Tune V4L2 camera publish path`
- Non-`fis-teria` remotes were checked and left untouched.

### Baseline Measurement

Launch:

```bash
E2E_LIGHTWEIGHT_PRESET=fp16_minimal \
E2E_EXTRA_LAUNCH_ARGS='lead_probe_on_startup:=false e2e_input_preprocess_backend:=cpu' \
./launch_shadow_mode_e2e_transfuser.sh
```

Observed:

- `/shadow/e2e/status`: about 10.0Hz.
- Python Image subscriber measurement saw camera/overlay at about 1.7Hz.
- Because full-resolution `1920x1280 yuv422` images are large, the Python
  measurement subscriber itself may be part of the bottleneck. Next step is to
  use lighter status signals and reduce GUI input payload pressure.

### Change 1: Disable GUI Raw Camera Fallback By Default In run_gui.sh

Rationale:

- The GUI prefers `/shadow/e2e/overlay_image`, but subscribing to the raw
  `/sensing/camera/camera0/image_rect_color` topic still forces full-resolution
  `1920x1280 yuv422` Image delivery into the Python GUI process.
- For E2E display, the overlay image is already downscaled and is the intended
  GUI surface.

Implementation:

- Added `--no-ros-camera-raw-fallback`.
- `gui/run_gui.sh` now defaults `ROS_CAMERA_RAW_FALLBACK=0`, so the GUI subscribes
  to overlay only unless explicitly overridden.
- Direct GUI CLI behavior keeps raw fallback available by default.

Result:

- GUI confirmed `Raw camera image fallback subscription disabled`.
- Overlay still stayed around 1.5-1.7Hz, so GUI raw subscription was not the
  primary limiter.

### Finding: E2E Python Full-Resolution Subscription Limits Camera Publish Rate

Checks:

- Camera-only bringup diagnostics: `Publish rate: 9.79`, OK.
- Shadow launch with overlay enabled but E2E disabled: `Publish rate: 10.38`, OK.
- Shadow launch with E2E Python subscribing to full-resolution camera: about 1.7Hz.

Conclusion:

- The V4L2 publisher and C++ overlay path can sustain 10Hz.
- The full-resolution Image delivery into the Python E2E runtime is the main
  backpressure source.

### Change 2: Add C++ Model Input Image Topic

Implementation:

- `e2e_path_overlay` now publishes `/shadow/e2e/model_input_image` as `rgb8`
  `1152x384` from the same full-resolution camera frame it already consumes.
- `shadow_mode_e2e_transfuser.launch.py` now points E2E Python at that small model
  input image by default and disables raw image fallback subscriptions.
- This keeps full-resolution camera delivery to one C++ subscriber and gives the
  Python model node a much smaller image.

Result:

- E2E Python started with `images=['/shadow/e2e/model_input_image']`.
- `/shadow/e2e/status` stayed at about 10.0Hz.
- Camera diagnostics improved, but GUI raw `Image` overlay delivery was still
  below 10Hz.

### Change 3: Drive V4L2 Capture At The Target Rate

Implementation:

- `camera_lidar_bringup` now accepts `camera_time_per_frame:=auto`.
- When `camera_publish_rate:=10.0`, the generated V4L2 parameter file sets
  `time_per_frame: [1, 10]`.

Result:

- V4L2 reported `Current time per frame: 1/10 s`.
- Diagnostics showed `Effective rate status: OK`.
- `/shadow/e2e/status`: about 10.0Hz with roughly 100ms frame intervals.

### Finding: Python GUI Raw Image Transport Is The Remaining Display Bottleneck

Observed:

- C++ overlay status was near 10Hz.
- GUI receiving raw `sensor_msgs/Image` overlay was only about 3.5-4.5Hz even
  after raw camera fallback, demo updates, and ROS spin timing were reduced.
- Reducing the raw overlay image from 640px max edge to 320px did not materially
  improve the GUI receive rate.

Conclusion:

- The E2E loop and overlay producer can sustain 10Hz.
- The GUI should not use raw `Image` messages for the live overlay display path
  if the goal is stable 10Hz.

### Change 4: Publish And Prefer Compressed Overlay For GUI

Implementation:

- `e2e_path_overlay` now also publishes
  `/shadow/e2e/overlay_image/compressed` as `sensor_msgs/CompressedImage` JPEG.
- `gui/run_gui.sh` defaults to the compressed overlay topic and disables raw
  overlay fallback unless `ROS_CAMERA_RAW_OVERLAY_FALLBACK=1` is set.
- ROS2-first GUI mode keeps the demo data source idle to avoid unnecessary
  10Hz repaint work.
- ROS2 GUI callbacks run in a background spin thread and cross into PyQt through
  signals.

Result:

- GUI log:
  - `19:10:34 Camera overlay compressed frame 1`
  - `19:10:44 Camera overlay compressed frame 100`
  - `19:10:54 Camera overlay compressed frame 200`
  - `19:11:04 Camera overlay compressed frame 300`
  - `19:11:15 Camera overlay compressed frame 400`
  - `19:11:25 Camera overlay compressed frame 500`
  - `19:11:35 Camera overlay compressed frame 600`
- `/shadow/e2e/status`: about 10.0Hz.
- `/shadow/e2e/overlay_image/compressed`: about 10.0Hz.
- V4L2 diagnostics sample: publish rate `9.46`, status OK.

## Current Status

- ShadowMode E2E processing: 10Hz achieved.
- C++ overlay production: 10Hz achieved.
- GUI displayed camera overlay path: 10Hz achieved using compressed overlay.

Residual notes:

- Raw `sensor_msgs/Image` overlay remains too slow for the Python GUI path.
- Some nodes still print shutdown-only ROS errors when interrupted; they did not
  affect the steady-state 10Hz measurements above.

### Change 5: Decouple GUI PointCloud Parsing From Camera Callbacks

Rationale:

- When PointCloud2 traffic starts, parsing and sampling it inside the ROS callback
  can block the GUI's single ROS executor long enough for camera overlay callbacks
  to look stalled.
- The left-side GUI starts on Camera view, so PointCloud2 should not spend CPU
  unless the PointCloud view is actually visible and using the ROS2 source.
- The PointCloud view previously recomputed its scene range from each incoming
  cloud, which made the virtual viewer camera zoom in and out as the cloud extent
  changed.

Implementation:

- PointCloud2 callbacks now only store the latest message and return quickly.
- A dedicated GUI pointcloud worker parses the latest cloud at the configured
  low update rate.
- The worker is enabled only when the left PointCloud view is selected and the
  Cloud source is ROS2.
- PointCloud view now uses the configured fixed range and fixed height color range
  instead of auto-fitting every frame.
- GUI docs now align the default PointCloud2 topic with FAST-LIO
  `/cloud_registered`, with `/livox/lidar` documented as an override for raw-frame
  viewing.

Validation:

- `python3 -m py_compile gui/lib/data_sources.py gui/lib/main_window.py gui/lib/pointcloud_view.py gui/lib/app.py`
- Live ROS topic validation was not rerun in this step because no camera/LiDAR
  topics were active in the current shell.

### Change 6: Add Shadow Route Target Bridge

Rationale:

- `e2e_transfuser` treats `/shadow/route/target_point` as an input, not as an
  output discovered from camera scenery.
- The active Shadow Mode stack already generates `/shadow/virtual/path` from
  `livox_lane_detection` scan or PointCloud2 via `shadow_mode_virtual_control`.
- E2E should receive a fresh route target from that Shadow path, while leaving an
  interface for future GUI route and camera white-line / road-shoulder paths.

Implementation:

- Added `shadow_route_target`.
- It subscribes to `/shadow/route/gui_path`, `/shadow/perception/lane_path`, and
  `/shadow/virtual/path` in that priority order.
- It selects a configurable lookahead point, default `15m`, and publishes
  `/shadow/route/target_point` plus `/shadow/route/target_status`.
- `shadow_mode_bringup` now starts the route target bridge by default.
- `shadow_mode_e2e_transfuser.launch.py` forwards the E2E target topic and route
  target parameters into Shadow Mode bringup.

Current interface contract:

- GUI route IF: publish `nav_msgs/Path` to `/shadow/route/gui_path` in `base_link`.
- Camera white-line / road-shoulder IF: publish `nav_msgs/Path` to
  `/shadow/perception/lane_path` in `base_link`.
- Existing Shadow Mode source: `/shadow/virtual/path`.

### Change 7: Add Dedicated Camera Lane Model Adapter

Rationale:

- The current YOLO path is for object detection / tracking bbox overlay, not for
  white-line or road-shoulder route extraction.
- Camera-side route target generation should use a dedicated lane / road-shoulder
  segmentation model and feed the existing `/shadow/perception/lane_path` IF.

Implementation:

- Added `camera_lane_detection`.
- It subscribes to the camera image and camera info, loads a dedicated ONNX
  semantic segmentation model through OpenCV DNN, converts the lane / road-edge
  mask into a local `base_link` `nav_msgs/Path`, and publishes it to
  `/shadow/perception/lane_path`.
- It publishes `/shadow/perception/lane_status` JSON for missing-model and runtime
  diagnosis.
- `shadow_mode_e2e_transfuser.launch.py` exposes `use_camera_lane_detection`,
  `camera_lane_detection_model_path`, and processing-rate/input-size controls.

Current behavior:

- `use_camera_lane_detection:=false` by default, so the 10Hz lightweight path does
  not spend camera/GPU budget before a real model is installed.
- If enabled without a valid model path, the node publishes status only and does
  not publish a fake lane path.

### Change 8: Keep Camera Lane And Route Target From Blocking 10Hz

Finding:

- With `use_camera_lane_detection:=true` and no lane model installed,
  `camera_lane_detection` still subscribed to full-size `1920x1280 yuv422` images.
  That status-only path measured around 14% CPU.
- `shadow_virtual_control` can publish an empty `/shadow/virtual/path` when the
  current PointCloud2 source is too sparse or not lane-boundary shaped.
- Empty GUI/image/virtual route paths left `/shadow/route/target_point` missing,
  which made E2E report `missing_inputs: ["target_point"]` and stop path/overlay
  output.

Implementation:

- `camera_lane_detection` now subscribes to raw camera images only after a valid
  model has been loaded. Missing-model mode publishes status from a lightweight
  timer with `image_subscription_active: false`.
- `shadow_mode_e2e_transfuser.launch.py` now enables
  `route_target_publish_default_when_missing:=true` by default for the E2E wrapper,
  publishing a straight-ahead `base_link` fallback target at 15m when all route
  path sources are empty.

Validation:

- `camera_lane_detection` with the default empty `model_path` showed no
  subscribers in `ros2 node info /camera_lane_detection`.
- `/shadow/perception/lane_status` reported `reason: missing_model_path` and
  `image_subscription_active: false`.
- `shadow_route_target publish_default_when_missing:=true` published
  `/shadow/route/target_point` at about 9.995Hz with target `(x=15.0, y=0.0)`.

### Change 9: Add Overlay Stage Timing

Finding:

- `e2e_path_overlay` was the next suspect because E2E status stayed near 10Hz
  while `/shadow/e2e/overlay_image/compressed` stayed below 10Hz.
- Stage timing shows the actual drawing work is small. The heavier overlay-node
  stages are image conversion for model input and the overlay downscale/convert.

Implementation:

- `/shadow/e2e/overlay_status` now includes `timing_ms` with:
  `total`, `overlay_convert`, `model_input`, `tf_lookup`, `project`, `yolo`,
  `draw`, `image_publish`, and `jpeg_publish`.
- `shadow_mode_e2e_transfuser.launch.py` now uses a dedicated
  `e2e_overlay_input_image_topic` argument so overlay input is isolated from
  generic camera launch arguments.

Validation:

- With `1920x1280 yuv422` input, `output_max_edge_px=640`, and
  `model_input=1152x384`, overlay status-only sampling measured:
  - `total`: avg 6.62ms, p95 11.95ms
  - `model_input`: avg 3.26ms, p95 6.01ms
  - `overlay_convert`: avg 1.94ms, p95 3.78ms
  - `jpeg_publish`: avg 1.05ms, p95 1.76ms
  - `draw`: avg 0.18ms, p95 0.28ms
- Camera diagnostics still reported about 9.62Hz, while overlay status measured
  about 7.89Hz in that run. This points more to raw image delivery / scheduling
  drops under system load than to expensive path drawing.
