# SAR Modes Executor

This package implements Search and Rescue (SAR) swarm formation modes for PX4 using the PX4-ROS2 Interface Library.
It registers two custom flight modes, **SAR (V-Sweep)** and **SAR (Orbital)**, on every vehicle that runs it, each computing a per-drone formation offset around a tracked target (e.g. a rover) streamed on `/rover/pose`.

## Overview

`BaseSARMode` subscribes to `/rover/pose` (`geometry_msgs/msg/PoseStamped`, assumed ROS ENU), converts the target's position and heading to NED, and exposes them to the derived modes:

- **SARVSweepMode** — holds a V/wedge formation around the target: the drone closest to the middle of the swarm leads, the others trail on either wing. The wedge is rotated by the target's heading so it stays pointed the way the target is facing.
- **SAROrbitalMode** — circles the target at a fixed radius, with drones evenly spaced around the circle and stacked at different altitudes so they don't collide; each drone yaws to face inward, toward the target.

Both modes are registered independently (no `ModeExecutorBase`/chaining), so they show up as two separately selectable flight modes in QGroundControl on each vehicle.

## Prerequisites

This exercise runs 3 drones at once, using this repo's multi-vehicle convention (1-indexed PX4 instances, see [`px4_tf/README.md`](../px4_tf/README.md)): `-i 1` → namespace `/px4_1/...`, `-i 2` → `/px4_2/...`, `-i 3` → `/px4_3/...`.

Everything runs inside the [dockerized dev environment](../../docs/setup_docker.md). Start the container and build PX4 + the workspace once per container session:

```sh
./docker/docker_run.sh ~/PX4-Autopilot
```

```sh
cd /PX4-Autopilot && make px4_sitl_default
cd /workspace && colcon build --symlink-install --packages-select sar_modes && source install/setup.bash
```

Then start QGroundControl on the host, or however you'd otherwise arm and activate flight modes (see [`docs/setup_docker.md`](../../docs/setup_docker.md) for download instructions). It talks MAVLink directly to each SITL instance, independent of ROS/DDS, and should auto-discover all 3 vehicles.

## Usage

`sar_modes.launch.py` now brings up the whole exercise in one shot: Gazebo + the ROS-GZ bridge + `MicroXRCEAgent` (via `px4_roscon_workshop`'s `gz_world.launch.py`), all 3 `x500` PX4 instances spread apart in the world (via `px4_vehicle.launch.py`), one `sar_modes` node per drone (namespaced `px4_1`/`px4_2`/`px4_3`, each told its own `drone_id` via a ROS parameter), and `fake_rover_mover.py` — no rover simulation model needed, just the pose stream:

```sh
ros2 launch sar_modes sar_modes.launch.py px4_autopilot_path:=/PX4-Autopilot
```

(`px4_autopilot_path` defaults to the `PX4_PATH` env var, which `docker_run.sh` already sets to `/PX4-Autopilot` — so inside the container you can usually drop the argument entirely.)

> This spawn plumbing (`gz_world.launch.py` + `px4_vehicle.launch.py`) is shared with [`formation_control`](../formation_control/README.md); the coordination logic isn't — SAR tracks one external target, `formation_control` tracks its neighbors.

`fake_rover_mover.py` starts at 5m East / 3m North with a ~45° heading, sits still once for `rover_start_delay` seconds (default 3s), then loops indefinitely (until the node is stopped): drives straight at `rover_min_linear_speed` (default 0.2 m/s) for `rover_straight_duration` seconds (default 45s), then circles at `rover_max_linear_speed` (default 0.8 m/s) around `rover_circle_radius` (default 5.0m, clamped to a 5m minimum) for `rover_num_circle_turns` full turns (default 2.0), then back to straight, repeating. The speed change between phases lets a speed-based mode switcher (see [`sar_auto_executor`](../sar_auto_executor/README.md)) actually exercise both sides of its threshold in one run. All of these are launch args (`rover_start_x`, `rover_start_y`, `rover_start_yaw_deg`, `rover_min_linear_speed`, `rover_max_linear_speed`, `rover_start_delay`, `rover_straight_duration`, `rover_circle_radius`, `rover_num_circle_turns`) if you want to change them. Sanity-check it's actually streaming (and moving, after the start delay) with:

```sh
ros2 topic echo /rover/pose
```

Once everything is up:

1. In QGroundControl, switch to each of the 3 vehicles (vehicle selector, top-left), arm, and take off manually to some altitude — there is no scripted auto-takeoff here since `BaseSARMode` is a bare `ModeBase`, not paired with a `ModeExecutorBase` like the other demos in this repo.
2. Once airborne, select **SAR (V-Sweep)** from the flight-mode dropdown. Each drone should move to the fake rover's position plus its own wedge offset, oriented along the rover's heading.

## Skipping QGroundControl (CLI-only mode selection)

You don't need QGroundControl to arm, take off, or switch modes — the PX4 SITL console (the `pxh>` shell in each `px4_vehicle.launch.py` pane) can do all of it directly. `docker_run.sh` currently requires an X11 `DISPLAY` (there's no `--no-gui`/headless container mode), so this only drops the QGroundControl dependency, not the GUI container itself.

In each vehicle's own `pxh>` console:

```
commander status              # confirm ext1 = SAR (V-Sweep), ext2 = SAR (Orbital)
commander arm -f              # -f forces arming, skips pre-arm checks that are noisy in SITL
commander takeoff
commander mode ext1           # switch to SAR (V-Sweep) once airborne
```

`extN` numbering follows registration order — since `main()` in `SARMode.cpp` constructs `SARVSweepMode` before `SAROrbitalMode`, `ext1` should be `SAR (V-Sweep)` and `ext2` `SAR (Orbital)`, but confirm with `commander status`'s output rather than assuming, in case behavior differs by PX4 version.

> Note: this `commander mode extN` syntax comes from a [PX4 forum thread](https://discuss.px4.io/t/px4-control-interface-how-to-execute-modes-without-qgc/41637), not the official docs (which only document the QGC flow) — treat `commander status`'s own output as the source of truth if something looks off.
