#!/bin/bash
# Point apt at a frozen snapshot of the ROS 2 package repository and move
# every installed ROS package onto it, so the whole image comes from one
# package sync. Mixing syncs breaks ABI (e.g. rviz2 failing on missing
# service_msgs symbols).
#
# usage: use-ros-snapshot.sh <distro> <YYYY-MM-DD> <path to snapshot key>
set -euo pipefail
distro=$1 date=$2 key=$3
codename=$(. /etc/os-release && echo "$VERSION_CODENAME")

install -D -m 0644 "$key" /etc/apt/keyrings/ros-snapshots.asc
# ros2-apt-source owns the floating packages.ros.org source file; upgrading
# it would put that file back, so remove the package itself.
if dpkg -s ros2-apt-source >/dev/null 2>&1; then
  dpkg --purge ros2-apt-source
fi
rm -f /etc/apt/sources.list.d/ros2.sources /etc/apt/sources.list.d/ros2*.list
cat > /etc/apt/sources.list.d/ros2-snapshot.sources <<SOURCES
Types: deb
URIs: http://snapshots.ros.org/${distro}/${date}/ubuntu
Suites: ${codename}
Components: main
Signed-By: /etc/apt/keyrings/ros-snapshots.asc
SOURCES

apt-get update
apt-get dist-upgrade -y --no-install-recommends
rm -rf /var/lib/apt/lists/*

if grep -rqs "packages.ros.org" /etc/apt/sources.list /etc/apt/sources.list.d/; then
  echo "FATAL: a floating packages.ros.org apt source is still configured" >&2
  exit 1
fi
