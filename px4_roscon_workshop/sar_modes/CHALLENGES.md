# Challenges

SAR shares roughly 2 hours with precision landing and custom modes, so treat this as a menu, not a checklist. Do the warm-up, pick one or two from Core, and only look at Stretch if you're way ahead of schedule.

These are all about the modes themselves — formation math, tracking, mode-level PX4 API. `sar_auto_executor` has its own separate list about the executor. Different concerns, not a continuation of this one.

## Warm-up (~15 min)

- [ ] Retune the formation. Bump `SARVSweepMode`'s spacing constants (`8.0f`/`10.0f`/`6.0f` in `updateSetpoint`) or `SAROrbitalMode`'s altitude step (`0.3f`), rebuild, and check the new numbers hold up with `ros2 topic echo /px4_N/fmu/out/vehicle_local_position`.

## Core (pick 1-2, ~30-45 min each)

- [ ] `SAROrbitalMode`'s radius and omega are fixed at construction. There's a `_param_mutex` sitting there unused for exactly this — wire up `add_on_set_parameters_callback` so `ros2 param set` can change the orbit while armed.
- [ ] Design a new formation from scratch, e.g. a grid/lawnmower sweep. Same building blocks as V-Sweep/Orbital: NED conversion, per-drone offset, yaw, altitude layering.
- [ ] Minimum-separation enforcement — if a formation configuration would put two drones too close, push them apart.

## Stretch

- [ ] Swap `fake_rover_mover.py` for a real Gazebo ground vehicle with its own sensor/odometry bridge.
- [ ] Multi-target support: track and assign drones across several rovers at once instead of one shared target.

## Take-home

No rush on any of these.

- [ ] Bug hunt: have someone plant one small bug (flipped sign in ENU→NED, swapped side/forward offset, wrong rotation axis) and find it purely from `ros2 topic echo`/`commander status`, no source diff.
- [ ] Plot the offset formulas for a few `drone_id`s in matplotlib. No ROS involved, just a way to see the geometry before touching flight code.
- [ ] `BaseSARMode::onActivate()`/`onDeactivate()` logs are pretty bare. Add `drone_id`/namespace so three interleaved consoles are actually readable.
- [ ] Add a `checkArmingAndRunConditions` override that blocks activation if `/rover/pose` has gone stale.
- [ ] `trajectory.hpp`'s own docs say `GotoSetpointType` should be preferred over what we're using. Try it in one mode, compare.
- [ ] Make the wedge spacing scale with rover speed — finite-difference `/rover/pose` yourself, don't borrow anything from `sar_auto_executor`.
- [ ] Extrapolate `_target_pos` using the rover's last velocity instead of just its last position, to claw back some of the tracking lag.
- [ ] The pose callback trusts every `/rover/pose` message as-is. A basic filter (or a full Kalman filter, if you want the challenge) on `_target_pos`/`_target_yaw` would help.
- [ ] `total_drones` is a hardcoded `3` in the launch file instead of a real launch arg. Fix it with the same `_float_param` pattern already used elsewhere (just needs `value_type=int`).
- [ ] Turn the "copy `romfs` per instance, `-i N`" dance into a shell script instead of doing it by hand every time.
- [ ] Script the "Headless / CLI-only testing" section end to end and check exit codes instead of eyeballing it.
- [ ] A real collision solver across the whole formation, not just pairwise pushes on top of fixed offsets.
- [ ] Pull the ENU→NED and offset math out of `updateSetpoint()` into standalone functions and actually unit test them.
- [ ] The altitude layering only holds up while a SAR mode is actively in control. If a node dies, or a drone falls back into Hold/RTL on its own, PX4's RTL altitude is one fixed value for the whole vehicle with zero awareness of the formation — two drones can end up recovering at the same height with nothing coordinating between them. Making that vary per `drone_id` would need PX4 parameter access from ROS2, and it turns out that doesn't exist here: `px4_ros2_cpp` has no parameter API at all, and this build doesn't bridge the raw `px4_msgs` parameter topics either (checked live, twice, with instances up — zero parameter topics among ~100 bridged `fmu` topics). The real fix is extending `px4_ros2_cpp` upstream, or rebuilding this PX4 image's DDS topic list. Short of that, `param set RTL_RETURN_ALT` per instance (each already has its own `romfs` copy) gets you there manually.
