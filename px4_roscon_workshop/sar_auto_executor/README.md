# SAR Auto Executor

This package builds on [`sar_modes`](../sar_modes/README.md): same **SAR (V-Sweep)** and **SAR (Orbital)** formation modes, plus a new **SAR (Auto)** mode that automatically switches between them based on the tracked rover's speed — no manual mode selection needed once armed.

## Overview

`SARModeExecutor` (`px4_ros2::ModeExecutorBase`) owns a thin placeholder mode, **SAR (Auto)** (`SARAutoMode`), which is the only thing pilots select in QGC/`commander`. The executor tracks the rover's speed itself, from consecutive `/rover/pose` messages, and calls `scheduleMode(...)` to switch the vehicle's *actual* active mode:

- Speed **below 0.3 m/s** → `scheduleMode` into **SAR (Orbital)**
- Speed **at or above 0.6 m/s** → `scheduleMode` into **SAR (V-Sweep)**
- Between 0.3 and 0.6 m/s → stays in whichever mode is already active (hysteresis, to avoid rapid flapping)

`SAR (V-Sweep)` and `SAR (Orbital)` are still registered as independent modes too — same as in `sar_modes` — so you can still select either of them manually if you want to override the executor's decision (e.g. for the manual exercise, or debugging). `SAR (Auto)` is the *new* entry that hands control over to the executor's logic.

`fake_rover_mover.py` now drives at two different speeds per phase — `rover_min_linear_speed` (default 0.2 m/s, straight phase) and `rover_max_linear_speed` (default 0.8 m/s, circle phase) — which straddle both thresholds by default, so a single run exercises the switch both ways without needing to override anything.

## Prerequisites

Same as [`sar_modes`](../sar_modes/README.md#prerequisites) — Gazebo, 3 PX4 instances (1-indexed, `-i 1`/`-i 2`/`-i 3`, each with its own `romfs` copy — see that README for why), QGroundControl.

## Usage

1. Launch the common launchfile (same as `sar_modes`):

   ```sh
   ros2 launch px4_roscon_workshop common.launch.py
   ```

2. Build and run `sar_auto_executor.launch.py`. It starts one `sar_auto_executor` node per drone (namespaced `px4_1`/`px4_2`/`px4_3`) plus `sar_modes`'s `fake_rover_mover.py` (reused, not duplicated — it's a test fixture, not part of this package's logic):

   ```sh
   colcon build --packages-select sar_modes sar_auto_executor
   source install/setup.bash
   ros2 launch sar_auto_executor sar_auto_executor.launch.py
   ```

3. In QGroundControl (or `commander`, see below), arm each vehicle and take off manually, then select **SAR (Auto)**. The executor should immediately schedule into V-Sweep or Orbital based on the rover's current speed, and keep switching automatically as the speed crosses the thresholds.

## CLI-only testing

Same `commander` flow as `sar_modes`'s README. With the executor involved there are 3 registered entries, and confirmed live (`commander --instance N status`) they share one `extN` counter — registration order was V-Sweep, Orbital, then the executor's owned Auto mode, giving:

```
External Mode 1: nav_state: 23, name: SAR (V-Sweep)
External Mode 2: nav_state: 24, name: SAR (Orbital)
External Mode 3: nav_state: 25, name: SAR (Auto)
Mode Executor 1: owned nav_state: 25, in charge: yes
```

So `ext3` is `SAR (Auto)`. The separate "Mode Executor" line isn't a competing numbering scheme — it just reports which executor owns which mode and whether it's currently in charge (note "in charge: yes" can show even while the *active* nav_state is 23, not 25 — being in charge means the executor is the one directing which mode runs via `scheduleMode`, not that the FMU's active state equals the owned mode's ID). Re-verify with `commander status` if you change registration order in `main()`, since this mapping isn't guaranteed to stay ext3 if that changes.

```
commander arm -f
commander takeoff
commander mode ext3            # switch to SAR (Auto)
```

If running via the CLI rather than an interactive `pxh>` console, use the `px4-commander` client symlink with `--instance` *before* the subcommand: `px4-commander --instance 2 status` (not `status --instance 2`).
