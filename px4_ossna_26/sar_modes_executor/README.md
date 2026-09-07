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

1. Start Gazebo:

   ```sh
   python3 /home/ubuntu/PX4-gazebo-models/simulation-gazebo --model_store /home/ubuntu/PX4-gazebo-models/ --world default
   ```

2. Spawn the 3 `x500` quadrotors, one PX4 instance each, spread apart so they don't overlap.

   **Important:** `-w` makes the process `chdir` into that exact path — confirmed empirically, it overrides the shell's own working directory, not the other way around. Each instance writes its runtime state (`dataman`, `parameters.bson`, `log/`) relative to wherever `-w` points, so multiple instances sharing the same `-w` path stomp each other's files. Symptoms: `Preflight Fail: No valid data from Baro 0` / `ekf2 missing data` that never clears on the non-first instances, while a lone instance works fine. Fix: give each instance its own copy of `romfs/` and point `-w` at that copy:

   ```sh
   cp -r /home/ubuntu/px4_sitl/romfs /home/ubuntu/px4_sitl/romfs_1
   cp -r /home/ubuntu/px4_sitl/romfs /home/ubuntu/px4_sitl/romfs_2
   cp -r /home/ubuntu/px4_sitl/romfs /home/ubuntu/px4_sitl/romfs_3
   ```

   ```sh
   PX4_GZ_STANDALONE=1 PX4_SYS_AUTOSTART=4001 PX4_SIM_MODEL=gz_x500 PX4_GZ_MODEL_POSE="0,0,0,0,0,0" PX4_PARAM_UXRCE_DDS_SYNCT=0 /home/ubuntu/px4_sitl/bin/px4 -w /home/ubuntu/px4_sitl/romfs_1 -i 1
   ```

   ```sh
   PX4_GZ_STANDALONE=1 PX4_SYS_AUTOSTART=4001 PX4_SIM_MODEL=gz_x500 PX4_GZ_MODEL_POSE="2,0,0,0,0,0" PX4_PARAM_UXRCE_DDS_SYNCT=0 /home/ubuntu/px4_sitl/bin/px4 -w /home/ubuntu/px4_sitl/romfs_2 -i 2
   ```

   ```sh
   PX4_GZ_STANDALONE=1 PX4_SYS_AUTOSTART=4001 PX4_SIM_MODEL=gz_x500 PX4_GZ_MODEL_POSE="4,0,0,0,0,0" PX4_PARAM_UXRCE_DDS_SYNCT=0 /home/ubuntu/px4_sitl/bin/px4 -w /home/ubuntu/px4_sitl/romfs_3 -i 3
   ```

3. Start QGroundControl (it talks MAVLink directly to each SITL instance, independent of ROS/DDS, and should auto-discover all 3 vehicles):

   ```sh
   /home/ubuntu/QGroundControl/qgroundcontrol
   ```

## Usage

1. Launch the common launchfile — this brings up the shared `MicroXRCEAgent` all 3 SITL instances connect to. Note: `px4_tf_publisher`/`robot_state_publisher` inside it are single-vehicle and unnamespaced, so with all 3 instances namespaced (`px4_1`/`px4_2`/`px4_3`) they just sit idle — harmless, not needed for this exercise.

   ```sh
   ros2 launch px4_ossna_26 common.launch.py
   ```

2. Build and run `sar_modes_executor.launch.py`. It starts one `sar_modes_executor` node per drone (namespaced `px4_1`/`px4_2`/`px4_3`, each told its own `drone_id` via a ROS parameter) plus `fake_rover_mover.py` — no rover simulation model needed, just the pose stream:

   ```sh
   colcon build --packages-select sar_modes_executor
   source install/setup.bash
   ros2 launch sar_modes_executor sar_modes_executor.launch.py
   ```

   `fake_rover_mover.py` starts at 5m East / 3m North with a ~45° heading, sits still once for `rover_start_delay` seconds (default 3s), then loops indefinitely (until the node is stopped): drives straight at `rover_min_linear_speed` (default 0.2 m/s) for `rover_straight_duration` seconds (default 45s), then circles at `rover_max_linear_speed` (default 0.8 m/s) around `rover_circle_radius` (default 5.0m, clamped to a 5m minimum) for `rover_num_circle_turns` full turns (default 2.0), then back to straight, repeating. The speed change between phases lets a speed-based mode switcher (see [`sar_auto_executor`](../sar_auto_executor/README.md)) actually exercise both sides of its threshold in one run. All of these are launch args (`rover_start_x`, `rover_start_y`, `rover_start_yaw_deg`, `rover_min_linear_speed`, `rover_max_linear_speed`, `rover_start_delay`, `rover_straight_duration`, `rover_circle_radius`, `rover_num_circle_turns`) if you want to change them. Sanity-check it's actually streaming (and moving, after the start delay) with:

   ```sh
   ros2 topic echo /rover/pose
   ```

3. In QGroundControl, switch to each of the 3 vehicles (vehicle selector, top-left), arm, and take off manually to some altitude — there is no scripted auto-takeoff here since `BaseSARMode` is a bare `ModeBase`, not paired with a `ModeExecutorBase` like the other demos in this repo.

4. Once airborne, select **SAR (V-Sweep)** from the flight-mode dropdown. Each drone should move to the fake rover's position plus its own wedge offset, oriented along the rover's heading.

## Headless / CLI-only testing (no GUI, no QGroundControl)

The whole exercise can run without any GUI at all — useful for headless boxes or CI.

**Container**: start it with `--no-gui` (see [`docs/setup.md`](../../docs/setup.md)):

```sh
./docker/docker_run.sh --no-gui
```

**Gazebo**: add `--headless` to the same command from Prerequisites step 1 — this is mandatory once the container itself has no GUI (see [`docs/simulation.md`](../../docs/simulation.md)):

```sh
python3 /home/ubuntu/PX4-gazebo-models/simulation-gazebo --model_store /home/ubuntu/PX4-gazebo-models/ --world default --headless
```

PX4 instance spawning (Prerequisites step 2) is unchanged — those commands don't touch the GUI.

**QGroundControl**: skip it entirely and use the `commander` CLI below instead. If you'd still rather use QGC, the `--no-gui` container exposes UDP port `18570` to the host, so you can run QGC on the host and add a custom UDP link to `127.0.0.1:18570` (a GUI-enabled container does not expose this port).

**Mode selection**: driven from the PX4 SITL console (the `pxh>` shell in each `px4` pane) instead of QGroundControl. Steps 1-2 of Usage above (`common.launch.py`, `sar_modes_executor.launch.py`) still apply unchanged.

In each vehicle's own `pxh>` console:

```
commander status              # confirm ext1 = SAR (V-Sweep), ext2 = SAR (Orbital)
commander arm -f              # -f forces arming, skips pre-arm checks that are noisy in SITL
commander takeoff
commander mode ext1           # switch to SAR (V-Sweep) once airborne
```

`extN` numbering follows registration order — since `main()` in `SARMode.cpp` constructs `SARVSweepMode` before `SAROrbitalMode`, `ext1` should be `SAR (V-Sweep)` and `ext2` `SAR (Orbital)`, but confirm with `commander status`'s output rather than assuming, in case behavior differs by PX4 version.

> Note: this `commander mode extN` syntax comes from a [PX4 forum thread](https://discuss.px4.io/t/px4-control-interface-how-to-execute-modes-without-qgc/41637), not the official docs (which only document the QGC flow) — treat `commander status`'s own output as the source of truth if something looks off.
