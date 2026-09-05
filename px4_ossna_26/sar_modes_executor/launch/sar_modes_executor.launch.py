from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def _float_param(launch_arg_name):
    return ParameterValue(LaunchConfiguration(launch_arg_name), value_type=float)


def generate_launch_description():

    rover_x_arg = DeclareLaunchArgument(
        "rover_start_x", default_value="5.0",
        description="Fake rover starting ENU X position [m]"
    )
    rover_y_arg = DeclareLaunchArgument(
        "rover_start_y", default_value="3.0",
        description="Fake rover starting ENU Y position [m]"
    )
    rover_yaw_arg = DeclareLaunchArgument(
        "rover_start_yaw_deg", default_value="45.0",
        description="Fake rover starting heading [deg]"
    )
    rover_speed_arg = DeclareLaunchArgument(
        "rover_linear_speed", default_value="0.5",
        description="Fake rover linear speed once moving [m/s]"
    )
    rover_angular_rate_arg = DeclareLaunchArgument(
        "rover_angular_rate_deg", default_value="5.0",
        description="Fake rover heading turn rate once moving [deg/s]"
    )
    rover_start_delay_arg = DeclareLaunchArgument(
        "rover_start_delay", default_value="3.0",
        description="Seconds the fake rover stays still before it starts moving"
    )

    fake_rover_pose = Node(
        package="sar_modes_executor",
        executable="fake_rover_mover.py",
        name="fake_rover_mover",
        output="screen",
        parameters=[
            {
                "start_x": _float_param("rover_start_x"),
                "start_y": _float_param("rover_start_y"),
                "start_yaw_deg": _float_param("rover_start_yaw_deg"),
                "linear_speed": _float_param("rover_linear_speed"),
                "angular_rate_deg": _float_param("rover_angular_rate_deg"),
                "start_delay": _float_param("rover_start_delay"),
            }
        ]
    )

    total_drones = 3
    # PX4 multi-vehicle instances are 1-indexed in this repo's convention
    # (see px4_ossna_26/px4_tf/README.md: -i 1 -> /px4_1/..., -i 2 -> /px4_2/...),
    # but the formation math in SARMode.cpp centers around a 0-indexed drone_id.
    # So the ROS namespace uses the PX4 instance id, while the drone_id
    # parameter passed to the node stays 0-indexed.
    drone_nodes = [
        Node(
            package="sar_modes_executor",
            executable="sar_modes_executor",
            name="sar_modes_executor",
            namespace=f"px4_{instance_id}",
            output="screen",
            parameters=[
                {
                    "use_sim_time": True,
                    "drone_id": instance_id - 1,
                    "total_drones": total_drones,
                }
            ]
        )
        for instance_id in range(1, total_drones + 1)
    ]

    return LaunchDescription([
        rover_x_arg,
        rover_y_arg,
        rover_yaw_arg,
        rover_speed_arg,
        rover_angular_rate_arg,
        rover_start_delay_arg,
        *drone_nodes,
        fake_rover_pose,
    ])
