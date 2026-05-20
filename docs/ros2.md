# Linking the simulation to ROS 2

With the simulation [up and running](simulation.md), it is time to bridge ROS 2 with Gazebo and PX4.

The following sections demo the essential steps in this process.
However, when trying the exercises you can leverage the [common launchfile](../px4_ossna_26/px4_ossna_26/README.md) which automatically sets up the required bridges.

1. **Clock bridging.**  We want to leverage the GZ clock and use it to time all our ROS 2 node.
This is accomplished by first creating an unidirectional bridge between the gz `/clock` topic and the ROS 2 one and then by commanding all ROS 2 to use the newly created `/clock` ROS 2 topic as time reference.
We will use the `ros_gz_bridge` package to create the bridge:

    ```sh
    ros2 run ros_gz_bridge parameter_bridge /clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock
    ```

    While the ROS 2 behavior will be set by the parameter `use_sim_time`.
2. **ROS 2 - PX4 bridge.** PX4 leverages [eProsima Micro XRCE-DDS](https://micro-xrce-dds.docs.eprosima.com/en/v2.4.3/) which internal [PX4 messages](https://docs.px4.io/v1.16/en/middleware/uorb) to be directly exposed to the ROS 2 network.
The simulated PX4 instance automatically start the Micro XRCE-DDS client using UDP protocol on port 8888, what we need to do is to just start the agent with the same settings.

    ```sh
    MicroXRCEAgent udp4 -p 8888
    ```

    after running this command you can see PX4 establish the connection - the expected output is a sequence of messages like

    ```sh
    INFO  [uxrce_dds_client] successfully created rt/fmu/out/vehicle_status_v1 data writer, topic id: 279
    INFO  [uxrce_dds_client] successfully created rt/fmu/out/airspeed_validated data writer, topic id: 14
    INFO  [uxrce_dds_client] successfully created rt/fmu/out/vtol_vehicle_status data writer, topic id: 288
    INFO  [uxrce_dds_client] successfully created rt/fmu/out/home_position data writer, topic id: 123
    ```

## Inspecting PX4 messages

Now that the [PX4 messages](https://docs.px4.io/v1.16/en/msg_docs/) are available to ROS 2, you can list them with

```sh
ros2 topic list
```

The messages in the topics with namespace `/fmu/in` are sent from ROS 2 to PX4 while the ones with namespace `/fmu/out` go from PX4 to ROS 2.

For example, you can check the PX4 vehicle status with

```sh
ros2 topic echo /fmu/out/vehicle_status_v1
```

You can also try the `sensor_combined_listener` node from the [px4_ros_com](https://github.com/PX4/px4_ros_com) package and get a user friendly visualization of PX4 accelerometer and gyroscope data:

```sh
ros2 run px4_ros_com sensor_combined_listener --ros-args -p use_sim_time:=true
```

It will output something like:

```sh
RECEIVED SENSOR COMBINED DATA
=============================
ts: 93380000
gyro_rad[0]: -0.000287732
gyro_rad[1]: -0.000181083
gyro_rad[2]: -0.00105683
gyro_integral_dt: 4000
accelerometer_timestamp_relative: 0
accelerometer_m_s2[0]: -0.00764366
accelerometer_m_s2[1]: 6.15756e-05
accelerometer_m_s2[2]: -9.79929
accelerometer_integral_dt: 4000
```

## Foxglove visualization

You can use the [px4_tf](../px4_ossna_26/px4_tf/README.md) packages, in conjunction with `foxglove_bridge` to visualize in 3D the drone `base_link`.

The `px4_tf_publisher` node subscribes to PX4 `/fmu/out/vehicle_odometry` topic and publishes a derived transform for the `odom` frame to the `base_link` frame.

```sh
ros2 run px4_tf px4_tf_publisher --ros-args -p use_sim_time:=true
```

Finally `foxglove_bridge` let's us visualize the tf in Foxglove.

```sh
ros2 run foxglove_bridge foxglove_bridge --ros-args -p use_sim_time:=true
```

Launch your Foxglove client and open a connection of type _Foxglove WebSocket_ with url `ws://localhost:8765`.

![foxglove example](./assets/foxglove.png)

**Note:** when restarting the simulations and the foxglove_bridge, you might have to restart Foxglove client too to re-establish the connection.

## Recompiling the ROS 2 workspace

To recompile the ROS 2 workspace

```sh
cd ~/ossna-26-workshop_ws/
source ~/px4_ros_ws/install/setup.bash
colcon build --symlink-install
```
