# Challenges

Most people won't get here in the shared SAR slot, and that's fine — it's a bonus track for whoever finishes [`sar_modes/CHALLENGES.md`](../sar_modes/CHALLENGES.md) early.

That list is about the modes themselves. This one's about the executor — `ModeExecutorBase`, `scheduleMode`, the switching decision. If you want more formation/API work, that's the wrong file.

## Quick (pick 1, ~15-20 min)

- [ ] `kSpeedLowThreshold`/`kSpeedHighThreshold` are compile-time constants right now. Make them ROS parameters like `drone_id`/`total_drones` already are, so the hysteresis band is tunable per launch without a rebuild.
- [ ] The README documents `ext1`=V-Sweep, `ext2`=Orbital, `ext3`=Auto, following the `doRegister()` order in `main()`. Swap that order, rebuild, and check with `px4-commander --instance N status` (instance flag goes *before* the subcommand) that the numbering actually follows — don't just take the README's word for it.

## Core (pick 1-2, ~30-45 min each)

- [ ] Add a third state to `evaluateAndSwitch()` — a hold/loiter triggered by the rover sitting still for a while, not just the two speed branches.
- [ ] `sendCommandSync`, `deferFailsafesSync`, and `waitReadyToArm` are all sitting unused on `ModeExecutorBase`. Pick one and use it for something real — defer failsafes briefly during a transition, say, or send a custom `MAV_CMD` on activation.

## Stretch

Chain in an automatic Takeoff before the executor starts watching speed, and Land/Disarm on some end condition — same idea as `custom_mode_demo`'s `switchToState`, just wrapped around the speed-based switching instead of a fixed sequence.

## Take-home

- [ ] Plant a bug in the hysteresis state machine (swap a comparison, swap which threshold does what) and find it live, not by diffing.
- [ ] `evaluateAndSwitch()` silently returns when nothing changes. Log the computed speed and which branch fired, so the decision is actually visible in real time.
- [ ] Speed is a single finite-difference between two messages right now, which is noisy. A small moving-average or low-pass filter would help — lighter weight than `sar_modes`'s tracking-filter challenge, just for this one number.
- [ ] The only way to see which mode is active right now is `nav_state` in `commander status`. Publish something — a topic, or just a periodic log — that says speed and active mode together.
- [ ] This package copies `SARMode.hpp`/`.cpp` instead of depending on `sar_modes`, same as `precision_land_executor` does relative to `precision_land`. Try the other way — an actual shared library — and write up what it costs versus what it buys. The repo's already chosen duplication twice, so the interesting part is *why*, not necessarily fixing it.
