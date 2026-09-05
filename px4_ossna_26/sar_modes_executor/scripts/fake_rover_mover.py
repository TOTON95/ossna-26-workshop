#!/usr/bin/env python3
"""Fake rover pose publisher for testing sar_modes_executor without a rover model.

Publishes a moving PoseStamped on /rover/pose (ROS ENU): stays put for
start_delay seconds, then moves in a straight line while smoothly turning its
heading (like a car doing a slow turn), so the SAR formation modes have a
real moving target to track instead of a static pose.
"""
import math

import rclpy
from geometry_msgs.msg import PoseStamped
from rclpy.node import Node


class FakeRoverMover(Node):

    def __init__(self):
        super().__init__('fake_rover_mover')

        self.declare_parameter('start_x', 5.0)
        self.declare_parameter('start_y', 3.0)
        self.declare_parameter('start_yaw_deg', 45.0)
        self.declare_parameter('linear_speed', 0.5)       # m/s
        self.declare_parameter('angular_rate_deg', 5.0)   # deg/s heading turn rate
        self.declare_parameter('start_delay', 3.0)        # seconds before motion begins
        self.declare_parameter('rate_hz', 10.0)

        self._x = self.get_parameter('start_x').value
        self._y = self.get_parameter('start_y').value
        self._yaw = math.radians(self.get_parameter('start_yaw_deg').value)
        self._speed = self.get_parameter('linear_speed').value
        self._angular_rate = math.radians(self.get_parameter('angular_rate_deg').value)
        self._start_delay = self.get_parameter('start_delay').value
        rate_hz = self.get_parameter('rate_hz').value

        self._dt = 1.0 / rate_hz
        self._elapsed = 0.0

        self._pub = self.create_publisher(PoseStamped, '/rover/pose', 10)
        self._timer = self.create_timer(self._dt, self._on_timer)

        self.get_logger().info(
            f'Fake rover starting at ({self._x:.1f}, {self._y:.1f}), '
            f'yaw {math.degrees(self._yaw):.0f} deg. Motion begins in '
            f'{self._start_delay:.1f}s: {self._speed} m/s, '
            f'turning {math.degrees(self._angular_rate):.1f} deg/s.'
        )

    def _on_timer(self):
        self._elapsed += self._dt

        if self._elapsed >= self._start_delay:
            self._yaw += self._angular_rate * self._dt
            self._x += self._speed * math.cos(self._yaw) * self._dt
            self._y += self._speed * math.sin(self._yaw) * self._dt

        msg = PoseStamped()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = 'map'
        msg.pose.position.x = self._x
        msg.pose.position.y = self._y
        msg.pose.position.z = 0.0
        msg.pose.orientation.z = math.sin(self._yaw / 2.0)
        msg.pose.orientation.w = math.cos(self._yaw / 2.0)
        self._pub.publish(msg)


def main():
    rclpy.init()
    node = FakeRoverMover()
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
