# Running the simulation

With the container running (see [Setup](setup.md)), this page shows how to
open the workshop's terminals and start the PX4 + Gazebo simulation.

> All commands are run from a terminal **inside the container**.

## Running several workshop commands in one window

The workshop's setup steps each occupy a terminal of their own. A typical run needs at least four shells inside the container at the same time:

1. Gazebo (`simulation-gazebo`) — runs in the foreground, prints physics + plugin messages.
2. PX4 SITL (`/home/ubuntu/px4_sitl/bin/px4 …`) — runs in the foreground, prints its uORB / mavlink startup log.
3. The workshop's _common launch_ (`ros2 launch px4_ossna_26 common.launch.py`) — starts the MicroXRCEAgent, clock bridge, foxglove bridge, etc.
4. The example you are running for that exercise (`ros2 launch offboard_demo …`, `ros2 run precision_land …`, and so on).

You _can_ open a fresh OS terminal for each of those and `docker exec -it px4-ossna-26 bash` four times, but that gets cumbersome. Two friendlier ways to do it in one window are below — pick whichever matches how you started the container.

### Option A — VSCode DevContainer integrated terminal (no extra setup)

If you started the workshop with `Dev Containers: Reopen in container`, VSCode is already _attached to the running container_ and every integrated terminal it opens is a shell inside that container. You do not need `docker exec` again.

1. Open the terminal panel with **Ctrl+`** (the backtick key) — or **View → Terminal**.
2. The first tab is already inside the container, at `/home/ubuntu/ossna-26-workshop_ws`. Run your first command there (for example, start Gazebo).
3. Click the **`+` icon** in the top-right of the terminal panel (next to the trash bin) to open a second tab. It is also inside the container.
4. Repeat for as many shells as you need. Each tab is independent: closing one doesn't kill the others.
5. To see two tabs side by side, click the **split icon** (the rectangle with a vertical line through it) next to `+`, or right-click a tab and pick **Split Terminal**.
6. Switch between tabs with **`Ctrl+PageDown` / `Ctrl+PageUp`**, or click the tab list on the right.

Tip: the workspace is bind-mounted, so when you edit a source file in VSCode and rebuild with `colcon build`, the new binary is immediately picked up by `ros2 run` / `ros2 launch` in the integrated terminal.

### Option B — `tmux` inside the container (works with plain `docker run`)

If you started the container with `./docker/docker_run.sh` (i.e. you are not in VSCode), use `tmux` to multiplex one OS terminal into many shells. The workshop image ships with `tmux` pre-installed, so there is nothing to install.

1. Attach the first terminal to the container as usual:

   ```sh
   docker exec -it px4-ossna-26 bash
   ```

2. Inside the container, start a `tmux` session:

   ```sh
   tmux
   ```

   You'll see a green status bar at the bottom — that means you are inside a `tmux` session. Every shortcut starts with the **prefix key**, which is `Ctrl+b` by default. Press the prefix, _release_ it, then press the next key.
3. Common shortcuts (each preceded by `Ctrl+b`, then released):

   | Shortcut | What it does |
   | --- | --- |
   | `"` | Split the current pane **horizontally** (new pane below) |
   | `%` | Split the current pane **vertically** (new pane to the right) |
   | `arrow keys` | Move focus between panes |
   | `c` | Create a new full-screen **window** (different from a pane) |
   | `n` / `p` | Next / previous window |
   | `0`-`9` | Jump to window N |
   | `z` | Zoom the current pane to full-screen / unzoom |
   | `x` | Close the current pane (asks for confirmation) |
   | `d` | **Detach** the session (it keeps running in the background) |
   | `?` | Show the full key reference |

4. A workshop-shaped layout, by hand, from a fresh `tmux`:

   ```text
   Ctrl+b "       # split horizontally   ───────────────
   Ctrl+b %       # split the new bottom pane vertically
   Ctrl+b arrow   # move focus
   ```

   gives you three panes — one for Gazebo on top, two stacked below for PX4 and the ROS 2 launches. Paste the relevant command into each.

5. To detach and free your terminal without killing anything, press `Ctrl+b` then `d`. The simulation keeps running. To reattach later (from a new `docker exec -it px4-ossna-26 bash`):

   ```sh
   tmux attach           # or:  tmux a
   ```

   If you have more than one session, `tmux ls` lists them and `tmux attach -t <name>` picks one.
6. To end everything cleanly: exit every shell in the session (`Ctrl+d` in each pane) or kill the whole session with `tmux kill-session`.

For people who are new to `tmux`: think of it as "screen-sharing for shells" — your single terminal window becomes a tiled layout of multiple independent bash sessions, and the session survives even if you accidentally close your terminal.

### Option C — the preconfigured workshop layout (`workshop-tmux`)

If you do not want to remember tmux's split commands at all, the image ships with a small launcher script that builds the layout for you. Run it instead of plain `tmux`:

```sh
docker exec -it px4-ossna-26 workshop-tmux
```

It creates a tmux session named `ossna` with two windows:

1. **`sim`** — a 6-pane grid (3 rows × 2 columns), each pane labelled in its border with the role it plays. Every long-running foreground process gets its own pane (`ros2 launch …` is foreground, so common and the examples can't share one). There are **two** example panes — `node 1` and `node 2` — because the teleop and precision-land exercises each run two ROS 2 nodes at the same time (e.g. `aruco_tracker` plus `precision_land`):

   ```text
   ┌───────────────────────────────┬───────────────────────────────┐
   │   gazebo                      │   px4                         │
   │   (paste simulation-gazebo)   │   (paste the PX4 SITL command)│
   ├───────────────────────────────┼───────────────────────────────┤
   │   ros2 common.launch.py       │   qgc                         │
   │   (paste `ros2 launch         │   (paste /home/ubuntu/        │
   │    px4_ossna_26               │    QGroundControl/            │
   │    common.launch.py`)         │    qgroundcontrol)            │
   ├───────────────────────────────┼───────────────────────────────┤
   │   ros2 node 1                 │   ros2 node 2                 │
   │   (first example node, e.g.   │   (second node, only teleop / │
   │    aruco_tracker.launch.py)   │    precision-land exercises)  │
   └───────────────────────────────┴───────────────────────────────┘
   ```

   Each pane is also pre-seeded with comment lines (`# ...`) showing the actual commands to paste. The shell treats those as comments and does nothing, so you can read the hint and either paste the suggested command verbatim or edit it (different `--world`, different airframe, different launchfile, etc.). For the offboard / custom-mode / aruco exercises the `node 2` pane simply stays empty.
2. **`scratch`** — a single empty pane for `ros2 topic echo`, `ros2 node list`, editing files with `nano` / `vim`, and anything else ad-hoc. Switch to it with `Ctrl+b n` (next window) or `Ctrl+b 1`.

The launcher also enables a couple of friendlier defaults on top of stock tmux: pane titles in the border, mouse mode (click to focus, scroll wheel works), 20 000 lines of scrollback, and vi keys in copy mode. All the keybindings from Option B still work, so once you are comfortable you can split / merge panes further.

Re-running `workshop-tmux` reattaches to the existing session instead of building a new one, so it is also a convenient way back in after `Ctrl+b d` (detach) or after closing your OS terminal:

```sh
docker exec -it px4-ossna-26 workshop-tmux   # builds session OR reattaches
```

To start fresh with a clean layout, kill the session first:

```sh
docker exec -it px4-ossna-26 tmux kill-session -t ossna
docker exec -it px4-ossna-26 workshop-tmux
```

## Starting the PX4-GZ simulation

PX4 can directly connect to GZ using the `gz-transport` libraries.
This means that PX4 can control any GZ model as long as the model uses the required sensor and actuation plugins.

For this workshop we will use the x500 quadrotor model.

![X500](./assets/X500.png)

The PX4 Gazebo worlds and models are available in the `/home/ubuntu/PX4-gazebo-models` container directory.
From there you can start a GZ simulation with a PX4 compatible world:

```sh
python3 /home/ubuntu/PX4-gazebo-models/simulation-gazebo --model_store /home/ubuntu/PX4-gazebo-models/ --world default
```

- If you want to run the gz server in headless mode, add the option `--headless`.
- If you want to change the world, then change the argument of `--world`.

Note that `--headless` is mandatory when running without GUI.

The expected output when GUI is enabled is

```sh
ubuntu@fe14532c7704:~$ python3 /home/ubuntu/PX4-gazebo-models/simulation-gazebo --model_store /home/ubuntu/PX4-gazebo-models/
Found: 219 files in /home/ubuntu/PX4-gazebo-models/
Models directory not empty. Overwrite not set. Not downloading models.
> Launching gazebo simulation...
QStandardPaths: XDG_RUNTIME_DIR not set, defaulting to '/tmp/runtime-ubuntu'
[Err] [SystemLoader.cc:92] Failed to load system plugin [libOpticalFlowSystem.so] : Could not find shared library.
[Err] [SystemLoader.cc:92] Failed to load system plugin [libGstCameraSystem.so] : Could not find shared library.
```

- Please ignore the error messages about the plugins not found.
- The gazebo client window will open on the empty world.
- No PX4 model will appear.
This is normal as PX4 instance and model will be spawned in a different step.

![empty GZ world](./assets/empty_gz_world.png)

Once the GZ server is running, you can spawn the `x500` model and attach a PX4 instance to it with

```sh
PX4_GZ_STANDALONE=1 PX4_SYS_AUTOSTART=4001 PX4_PARAM_UXRCE_DDS_SYNCT=0 /home/ubuntu/px4_sitl/bin/px4 -w /home/ubuntu/px4_sitl/romfs
```

The expected output is

```sh
$ PX4_GZ_STANDALONE=1 PX4_SYS_AUTOSTART=4001 PX4_PARAM_UXRCE_DDS_SYNCT=0 /home/ubuntu/px4_sitl/bin/px4 -w /home/ubuntu/px4_sitl/romfs
INFO  [px4] assuming working directory is rootfs, no symlinks needed.

______  __   __    ___ 
| ___ \ \ \ / /   /   |
| |_/ /  \ V /   / /| |
|  __/   /   \  / /_| |
| |     / /^\ \ \___  |
\_|     \/   \/     |_/

px4 starting.

INFO  [px4] startup script: /bin/sh etc/init.d-posix/rcS 0
env SYS_AUTOSTART: 4001
INFO  [param] selected parameter default file parameters.bson
INFO  [param] selected parameter backup file parameters_backup.bson
  SYS_AUTOCONFIG: curr: 0 -> new: 1
  SYS_AUTOSTART: curr: 0 -> new: 4001
  CAL_ACC0_ID: curr: 0 -> new: 1310988
  CAL_GYRO0_ID: curr: 0 -> new: 1310988
  CAL_ACC1_ID: curr: 0 -> new: 1310996
  CAL_GYRO1_ID: curr: 0 -> new: 1310996
  CAL_ACC2_ID: curr: 0 -> new: 1311004
  CAL_GYRO2_ID: curr: 0 -> new: 1311004
  CAL_MAG0_ID: curr: 0 -> new: 197388
  CAL_MAG0_PRIO: curr: -1 -> new: 50
  CAL_MAG1_ID: curr: 0 -> new: 197644
  CAL_MAG1_PRIO: curr: -1 -> new: 50
  SENS_BOARD_X_OFF: curr: 0.0000 -> new: 0.0000
  SENS_DPRES_OFF: curr: 0.0000 -> new: 0.0010
  UXRCE_DDS_SYNCT: curr: 1 -> new: 0
INFO  [dataman] data manager file './dataman' size is 1208528 bytes
INFO  [init] Gazebo simulator
INFO  [init] Standalone PX4 launch, waiting for Gazebo
INFO  [init] Gazebo world is ready
INFO  [init] Spawning model
INFO  [gz_bridge] world: default, model: x500_0
INFO  [lockstep_scheduler] setting initial absolute time to 2324000 us
INFO  [commander] LED: open /dev/led0 failed (22)
WARN  [health_and_arming_checks] Preflight Fail: ekf2 missing data
WARN  [health_and_arming_checks] Preflight Fail: No connection to the ground control station
INFO  [uxrce_dds_client] init UDP agent IP:127.0.0.1, port:8888
INFO  [tone_alarm] home set
INFO  [mavlink] mode: Normal, data rate: 4000000 B/s on udp port 18570 remote port 14550
INFO  [mavlink] mode: Onboard, data rate: 4000000 B/s on udp port 14580 remote port 14540
INFO  [mavlink] mode: Onboard, data rate: 4000 B/s on udp port 14280 remote port 14030
INFO  [mavlink] mode: Gimbal, data rate: 400000 B/s on udp port 13030 remote port 13280
INFO  [logger] logger started (mode=all)
INFO  [logger] Start file log (type: full)
INFO  [logger] [logger] ./log/2025-08-09/11_56_59.ulg
INFO  [logger] Opened full log file: ./log/2025-08-09/11_56_59.ulg
INFO  [mavlink] MAVLink only on localhost (set param MAV_{i}_BROADCAST = 1 to enable network)
INFO  [mavlink] MAVLink only on localhost (set param MAV_{i}_BROADCAST = 1 to enable network)
INFO  [px4] Startup script returned successfully
pxh> WARN  [health_and_arming_checks] Preflight Fail: No connection to the ground control station
WARN  [health_and_arming_checks] Preflight Fail: No connection to the ground control station
```

Let's analyze this command:

- `PX4_GZ_STANDALONE=1` tells the PX4 startup script that it will need to connect to an already running GZ server.
- `PX4_SYS_AUTOSTART=4001` tells the PX4 startup script that it has to use the `4001` _airframe_.
This airframe is defined in the [PX4 simulated airframes](https://github.com/PX4/PX4-Autopilot/tree/v1.16.0/ROMFS/px4fmu_common/init.d-posix/airframes) folder and is bound to the `x500` model.
Because not explicit model name was given, PX4 will insert the model in the GZ world.
An explicit mentioning of the model name would have made PX4 to simply connect to an already spawned model.
- `PX4_PARAM_UXRCE_DDS_SYNCT=0` disabled the [time synchronization](https://docs.px4.io/v1.16/en/ros2/user_guide#ros-gazebo-and-px4-time-synchronization) feature between ROS 2 and PX4.
Synchronization is not needed as Gazebo will control the clock for both PX4 and ROS 2.

The complete documentation for running PX4 simulation in Gazebo is part of [PX4 documentation](https://docs.px4.io/main/en/sim_gazebo_gz/).

![GZ world with x500 spawned](./assets/gz_world_with_x500.png)

Before taking off you just need to connect QGC to your simulated drone.
If you started you container with the GUI, then you can simply run

```sh
/home/ubuntu/QGroundControl/qgroundcontrol
```

If instead you don't have GUI in your container, then you can still run QGC on the host and attach it to the simulated PX4 instance.

To do so, first [install QGC](https://docs.qgroundcontrol.com/Stable_V5.0/en/qgc-user-guide/getting_started/download_and_install.html), then start it and create a custom UDP connection link by setting the server ip to `127.0.0.1` and the port to `18570`.

![QGC lin](./assets/qgc_custom_udp_connection.png)

The no-gui container automatically exposed the udp port `18570` to the host.
The GUI-enable container does not expose the port so this method won't for it.

On the PX4 terminal you will see the message

```sh
INFO  [mavlink] partner IP: 172.17.0.1
INFO  [commander] Ready for takeoff!
```

This is all you need to do to start the GZ + PX4 simulation, you can now takeoff!

---

**Next:** [Linking the simulation to ROS 2](ros2.md) — bridge PX4 and Gazebo into the ROS 2 graph.
