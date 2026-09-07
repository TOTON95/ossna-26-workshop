# SAR Auto Executor

This package builds on [`sar_modes_executor`](../sar_modes_executor/README.md): same **SAR (V-Sweep)** and **SAR (Orbital)** formation modes, plus a new **SAR (Auto)** mode that automatically switches between them based on the tracked rover's speed — no manual mode selection needed once armed.

## Overview

`SARModeExecutor` (`px4_ros2::ModeExecutorBase`) owns a thin placeholder mode, **SAR (Auto)** (`SARAutoMode`), which is the only thing pilots select in QGC/`commander`. The executor tracks the rover's speed itself, from consecutive `/rover/pose` messages, and calls `scheduleMode(...)` to switch the vehicle's *actual* active mode:

- Speed **below 0.3 m/s** → `scheduleMode` into **SAR (Orbital)**
- Speed **at or above 0.6 m/s** → `scheduleMode` into **SAR (V-Sweep)**
- Between 0.3 and 0.6 m/s → stays in whichever mode is already active (hysteresis, to avoid rapid flapping)

`SAR (V-Sweep)` and `SAR (Orbital)` are still registered as independent modes too — same as in `sar_modes_executor` — so you can still select either of them manually if you want to override the executor's decision (e.g. for the manual exercise, or debugging). `SAR (Auto)` is the *new* entry that hands control over to the executor's logic.

`fake_rover_mover.py` now drives at two different speeds per phase — `rover_min_linear_speed` (default 0.2 m/s, straight phase) and `rover_max_linear_speed` (default 0.8 m/s, circle phase) — which straddle both thresholds by default, so a single run exercises the switch both ways without needing to override anything.

## Prerequisites

Same as [`sar_modes_executor`](../sar_modes_executor/README.md#prerequisites) — Gazebo, 3 PX4 instances (1-indexed, `-i 1`/`-i 2`/`-i 3`, each with its own `romfs` copy — see that README for why), QGroundControl.

## Usage

1. Launch the common launchfile (same as `sar_modes_executor`):

   ```sh
   ros2 launch px4_ossna_26 common.launch.py
   ```

2. Build and run `sar_auto_executor.launch.py`. It starts one `sar_auto_executor` node per drone (namespaced `px4_1`/`px4_2`/`px4_3`) plus `sar_modes_executor`'s `fake_rover_mover.py` (reused, not duplicated — it's a test fixture, not part of this package's logic):

   ```sh
   colcon build --packages-select sar_modes_executor sar_auto_executor
   source install/setup.bash
   ros2 launch sar_auto_executor sar_auto_executor.launch.py
   ```

3. In QGroundControl (or `commander`, see below), arm each vehicle and take off manually, then select **SAR (Auto)**. The executor should immediately schedule into V-Sweep or Orbital based on the rover's current speed, and keep switching automatically as the speed crosses the thresholds.

## CLI-only testing

Same `commander` flow as `sar_modes_executor`'s README, but note: with the executor involved, there are now 3 registered entries (`SAR (Auto)`, `SAR (V-Sweep)`, `SAR (Orbital)`), and it's not yet confirmed here whether the executor's owned mode consumes the same `extN` numbering as a plain mode, or a separate counter (a PX4 forum note mentioned distinct "mode" vs "mode executor" registration counters). Check with `commander status` before assuming which `extN` is which:

```
commander status              # confirm which extN is SAR (Auto) vs V-Sweep vs Orbital
commander arm -f
commander takeoff
commander mode extN           # switch to whichever extN is SAR (Auto)
```
