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
    rover_min_speed_arg = DeclareLaunchArgument(
        "rover_min_linear_speed", default_value="0.2",
        description="Fake rover linear speed during the straight phase [m/s]"
    )
    rover_max_speed_arg = DeclareLaunchArgument(
        "rover_max_linear_speed", default_value="0.8",
        description="Fake rover linear speed during the circle phase [m/s]"
    )
    rover_start_delay_arg = DeclareLaunchArgument(
        "rover_start_delay", default_value="3.0",
        description="Seconds the fake rover stays still before it starts moving"
    )
    rover_straight_duration_arg = DeclareLaunchArgument(
        "rover_straight_duration", default_value="45.0",
        description="Seconds the fake rover drives straight before circling [s]"
    )
    rover_circle_radius_arg = DeclareLaunchArgument(
        "rover_circle_radius", default_value="5.0",
        description="Fake rover circling radius, minimum 5m [m]"
    )
    rover_num_circle_turns_arg = DeclareLaunchArgument(
        "rover_num_circle_turns", default_value="2.0",
        description="Number of full turns the fake rover circles before holding"
    )

    # Reuses sar_modes's fake rover publisher rather than duplicating
    # it here — it's a test fixture, not part of the mode-switching logic.
    fake_rover_pose = Node(
        package="sar_modes",
        executable="fake_rover_mover.py",
        name="fake_rover_mover",
        output="screen",
        parameters=[
            {
                "start_x": _float_param("rover_start_x"),
                "start_y": _float_param("rover_start_y"),
                "start_yaw_deg": _float_param("rover_start_yaw_deg"),
                "min_linear_speed": _float_param("rover_min_linear_speed"),
                "max_linear_speed": _float_param("rover_max_linear_speed"),
                "start_delay": _float_param("rover_start_delay"),
                "straight_duration": _float_param("rover_straight_duration"),
                "circle_radius": _float_param("rover_circle_radius"),
                "num_circle_turns": _float_param("rover_num_circle_turns"),
            }
        ]
    )

    total_drones = 3
    # Same 1-indexed PX4 instance / 0-indexed drone_id convention as
    # sar_modes (see px4_ossna_26/px4_tf/README.md).
    drone_nodes = [
        Node(
            package="sar_auto_executor",
            executable="sar_auto_executor",
            name="sar_auto_executor",
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
        rover_min_speed_arg,
        rover_max_speed_arg,
        rover_start_delay_arg,
        rover_straight_duration_arg,
        rover_circle_radius_arg,
        rover_num_circle_turns_arg,
        *drone_nodes,
        fake_rover_pose,
    ])
