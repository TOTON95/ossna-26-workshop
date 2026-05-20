# Setup

This page guides you through installing the workshop requirements and
starting the container. Once it is running, continue with
[Running the simulation](simulation.md).

The image contains all the dependencies required for the workshop, in particular:

- [GZ HARMONIC](https://gazebosim.org/docs/harmonic/getstarted/)
- [ROS 2 Humble](https://docs.ros.org/en/humble/index.html)
- [PX4](https://github.com/PX4/PX4-Autopilot) v1.16.0 simulator

To further simplify working in the container, VSCode [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers) are provided.

## Prerequisites

All the instructions and all the provided scripts have been tested on Ubuntu 22.04, Ubuntu 24.04 and WSL2.
Docker development in macOS is not supported.

- **Docker**. The easiest way to start using and testing the ROS 2 packages made for this workshop is through the available AMD64 and ARM64 [Docker](https://www.docker.com/) containers.
For this reason, the rest of the document will assume that Docker is used.
- **QGroundControl**. [GQC](https://qgroundcontrol.com/) provides intuitive operator control of PX4 drones, it lets you configure PX4, calibrate the drone sensors and plan mission.
QGC is already installed in the Docker images.
However, it requires GUI to enabled for the container.
If this is not possible (currently for MAC) then QGC will have to be installed on the host system.
- **Foxglove**. [Foxglove](https://foxglove.dev/download) will make visualizing the drone state and perceived environment a more user friendly way.

Prerequisites installation instructions are available in [docs/prerequisites.md](./prerequisites.md).

Once Docker is installed you can verify the installation by pulling the latest workshop docker image:

```sh
docker pull dronecode/ossna-26-workshop:latest
```

## Container structure

- Most of the required ROS 2 packages are installed through the available binaries:
  - [GZ HARMONIC](https://gazebosim.org/docs/harmonic/getstarted/)
  - [ROS 2 Humble](https://docs.ros.org/en/humble/index.html)
- Those packages that cannot be installed through binaries and that are dependencies for the main workshop exercise packages are source installed in `/home/ubuntu/px4_ros_ws/install`:

  - [Micro-XRCE-DDS-Agent](https://github.com/eProsima/Micro-XRCE-DDS-Agent) version 2.4.2
  - [PX4 msgs](https://github.com/PX4/px4_msgs) version 1.16
  - [PX4 ROS 2 Interface Library](https://github.com/Auterion/px4-ros2-interface-lib)
  - `ros_gz`

  Because one of the workshop exercises depends on OpenCV 4.10, `OpenCV`, `ros-humble-vision-opencv` and `ros-humble-image-common` are source installed too.

- [PX4 v1.16.0](https://px4.io/) simulator and its supported GZ Harmonic models and worlds.
- [GGroundControl](https://qgroundcontrol.com/) v5.0.8

### PX4 SITL

The docker image contains the binaries for running PX4 on linux, to interface it with Gazebo and all Gazebo models and worlds that support PX4.
The binaries are compiled in specific layer and to reduce the container size, only the final executables are copied in the final image.

- The binaries for PX4 are located in `/home/ubuntu/px4_sitl`
- The PX4 compatible GZ worlds and models are instead located in `/home/ubuntu/PX4-gazebo-models/`

Please refer to [docs/customize_px4.md](./customize_px4.md) to know how to use a custom version of PX4.

### QGroundControl

QGC v5.0.8 Linux Appimage is added and then extracted during the compilation of the docker AMD64 image.
If you're running on AMD64 with GUI, then you can open QGC directly from inside the container.

If instead you're running without GUI, then you will have to connect PX4 to a QGC instance running on the _host_.

## Starting the container

There are two ways to start and interact with the container: with pure Docker commands, or through VSCode DevContainers.

### Pure Docker commands

This mode does not require VSCode.
On the other hand it is slightly less user friendly as you'll have to open multiple terminals inside the container.

You can use

```sh
./docker/docker_run.sh
```

The script will:

- Start the container giving it the name _px4-ossna-26_ and attach a shell to it.
- Forward port `8765` to simplify Foxglove client connection.
- Mount the repository in `/home/ubuntu/ossna-26-workshop_ws/src/ossna-26-workshop`
- Forward X11 to run GUI applications (GZ client, QGC) from inside the container.

You can use also use these options:

- `--no-gui` to disable GUI in the container.
This option also forwards port `18570` to allow external (Host) QGC connection.
- `--nvidia` to run the container with the `nvidia` runtime (it requires the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed and registered with Docker on the host; see `nvidia-ctk runtime configure --runtime=docker` followed by `sudo systemctl restart docker`).
- `--tmux` to drop straight into the preconfigured workshop `tmux` layout (see [Option C](simulation.md#option-c--the-preconfigured-workshop-layout-workshop-tmux)) instead of a plain shell. Detaching the session (`Ctrl+b d`) leaves you in a normal shell with the simulation still running; reattach with `workshop-tmux`.

When using this method you can attach new shell to your container by running

```sh
docker exec -it px4-ossna-26 bash
```

From now on, all commands are assumed to be run from a terminal inside the container unless otherwise specified.

### VSCode DevContainers

To use the DevContainers, simply open the workshop repo in VSCode, then type `CTRL+SHIFT+P` and select `Dev Containers: Reopen in container`.
Finally, select the devcontainer of your choice.
VSCode will automatically reopen inside the running container.

## Troubleshooting

### T1: Gazebo GUI not showing

A1: Make sure you're running the container with GPU support.

### T2: on WSL2 I'm getting `docker: Error response from daemon: error gathering device information while adding custom device "/dev/dri": no such file or directory`

A2: Only `./docker/docker_run.sh --nvidia` combined with NVIDIA Container Toolkit works out of the box on WSL2.
If you don't have nvidia drivers or NVIDIA Container Toolkit installed on WSL2 you can run it headless `./docker/docker_run.sh --no-gui` or you can try removing `DOCKER_CMD="$DOCKER_CMD --device /dev/dri:/dev/dri"` from `./docker/docker_run.sh`.

### T3: `libEGL warning: egl: failed to create dri2 screen` when starting Gazebo on a hybrid Intel + NVIDIA host

A3: These warnings are harmless. On hybrid laptops, Mesa enumerates every `/dev/dri/renderD*` node and tries to build an EGL context on each one. The NVIDIA card cannot be driven by Mesa (it needs the proprietary driver), so EGL initialisation for that node fails and Mesa falls back to the Intel GPU. The Gazebo GUI still opens and renders correctly through Intel. If you want to use the NVIDIA card instead, install the NVIDIA Container Toolkit and run `./docker/docker_run.sh --nvidia`.

---

**Next:** [Running the simulation](simulation.md) — open the workshop terminals and start PX4 + Gazebo.
