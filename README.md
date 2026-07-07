# Open-RMF — compiled images for ease of use

Pre-built, ready-to-run Docker images for the [Open-RMF](https://www.openrmf.org/)
ecosystem: the ROS 2 simulation/fleet adapter stack, the REST API server, the web
dashboard, and the RMF Site Editor.

> Pick the branch that matches your ROS 2 distribution (e.g. branch `lyrical` for
> ROS 2 `lyrical`). Each branch pins the matching `ROS_DISTRO` build-arg in the
> Dockerfiles.

---

## Table of contents

- [Prerequisites](#prerequisites)
- [Build](#build)
- [Run](#run)
- [Accessing the services](#accessing-the-services)
- [Stop / tear down](#stop--tear-down)
- [Updating / rebuilding a single service](#updating--rebuilding-a-single-service)
- [Running GUI tools via `rocker`](#running-gui-tools-via-rocker)
  - [RMF Site Editor](#rmf-site-editor)
  - [Debugging Gazebo / RViz](#debugging-gazebo--rviz)
- [Notes & troubleshooting](#notes--troubleshooting)

---

Images are layered. `Dockerfile.rmf` is a **shared base** that compiles the core RMF packages from `repos/rmf.repos`. `Dockerfile.rmf-sim` and `Dockerfile.rmf-api-server` both derive from that base — they add only the apt/pip packages and build steps specific to their role. GUI/Qt/GL/X11/Gazebo packages and `flask-socketio` live in `rmf-sim` only; the api-server image is slimmer and has no GUI dependencies.

Four services come up under `docker-compose`. The first three are backend, the fourth is the web UI. All run **headless**; GUIs are launched separately on the host via `rocker` (see below).

| Service          | Image built from                | Role                                                                                |
|------------------|---------------------------------|-------------------------------------------------------------------------------------|
| `rmf-base`       | `docker/Dockerfile.rmf`         | Shared base: ROS 2 + RMF core packages from `rmf.repos`. Build-only; never runs.     |
| `rmf-sim`        | `docker/Dockerfile.rmf-sim`     | Base + Gazebo + Qt/GL/X11 + `rmf_demos`/`rmf_simulation` from `rmf-sim.repos`        |
| `zenoh-router`   | `eclipse/zenoh:...`             | Zenoh router run from upstream zenoh image |
| `api-server`     | `docker/Dockerfile.rmf-api-server` | `rmf-web`API server       |
| `rmf-web`        | `docker/Dockerfile.rmf-web-dashboard` | Static build of the `rmf-dashboard-framework` demo dashboard           |
| `rmf-site-editor`(GUI) | `docker/Dockerfile.site-editor` | RMF Site Editor desktop; build-only, launched via `rocker` |


A shared `./maps` directory is mounted into `rmf` so that maps authored in the Site Editor (also written into `./maps`) are visible to the simulator without any manual copying.

---

## Prerequisites

On the host machine:

- **Docker**, Compose plugin (`docker compose ...`)
- ~15 GB of free disk space 
- For GUI tools (`rocker` flow), also see the [Running GUI tools via rocker](#running-gui-tools-via-rocker) section.
- For NVIDIA GPU acceleration inside the containers, install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) on the host. 

Clone the repo and switch to the branch matching your ROS distro:

```bash
git clone https://github.com/nexsoss/Open-RMF.git
cd Open-RMF
git checkout lyrical   # or whichever ROS 2 distro branch you need
```

---

## Build

The whole stack is one command. `docker compose build` (or `compose up --build`on first run) builds each image in dependency order. Because the derived images (`rmf`, `api-server`) depend on the base, build the base first or rely on Compose's dependency resolution:

```bash
docker compose build rmf-base    # build the shared base explicitly (recommended)
docker compose build             # then build the rest
```

To build only a subset:

```bash
docker compose build rmf-sim        # just the RMF sim / fleet adapter image
docker compose build rmf-api-server # just the REST API image
docker compose build rmf-web        # just the dashboard image
```

The `zenoh-router` service pulls a prebuilt image.

## Run

Bring the whole stack up in the background:

```bash
docker compose up -d
```

This starts `rmf` → `zenoh-router` → `api-server` → `rmf-web` in the correct order.

To watch logs:

```bash
docker compose logs -f               # all services
docker compose logs -f rmf-sim       # just the RMF sim
```
---

## Accessing the services

| Service          | URL (from the host)                                | Notes                                              |
|------------------|----------------------------------------------------|----------------------------------------------------|
| `rmf-web`        | http://localhost:3000                              | Open-RMF web dashboard                             |
| `rmf-api-server` | http://localhost:8000                              | REST API (FastAPI / uvicorn)                       |
| `rmf-api-server` | ws://localhost:8080                                | WebSocket for live RMF state                       |
| `zenoh-router`   | (internal only — no published port)                | Zenoh router                                       |

---

## Stop / tear down

```bash
docker compose down            # stop and remove containers + the network
```

---

## Running GUI tools via `rocker`

GUI applications (RMF Site Editor, and Gazebo/RViz when visually debugging the simulation) are **not** part of `docker-compose`. They run on the host via
[`rocker`](https://github.com/osrf/rocker), which injects X11 / GPU configuration at container launch time. Compose stays clean and headless.

### 1. Install rocker (on the host, not inside any container)

```bash
sudo apt-get install python3-rocker
# or
pip install rocker
```

### 2. RMF Site Editor

The site-editor image is published as `quay.io/nexsoss/open-rmf:rmf-site-editor`. You can either pull the published image (recommended — no Rust toolchain needed) or build it locally.

**Pull from quay.io and launch:**

```bash
docker pull quay.io/nexsoss/open-rmf:rmf-site-editor

# Without an NVIDIA GPU:
rocker --x11 --user --volume ./maps:/root/site_maps \
    -- quay.io/nexsoss/open-rmf:rmf-site-editor

# With an NVIDIA GPU:
rocker --nvidia --x11 --user --volume ./maps:/root/site_maps \
    -- quay.io/nexsoss/open-rmf:rmf-site-editor
```

**Or build locally** 

```bash
docker build -f docker/Dockerfile.site-editor \
    -t quay.io/nexsoss/open-rmf:rmf-site-editor .

# Then launch with rocker using the same image reference as above:
rocker --x11 --user --volume ./maps:/root/site_maps \
    -- quay.io/nexsoss/open-rmf:rmf-site-editor
```

Exported map files (`.building.yaml` / SDF) land in `./maps` on the host.

### 3. Debugging Gazebo / RViz

`rmf` runs headless by default under compose. To visually debug Gazebo or RViz, launch the same image manually via rocker instead of changing anything in `docker-compose.yaml`. 

```bash
docker pull quay.io/nexsoss/open-rmf:lyrical_rmf-sim

rocker --nvidia --x11 --user \
    --volume ./maps:/home/ws_rmf/install/rmf_demos_maps/share/rmf_demos_maps/maps \
    -- quay.io/nexsoss/open-rmf:lyrical_rmf-sim \
    bash -c "source /opt/ros/lyrical/setup.bash && \
             source /home/ws_rmf/install/setup.bash && \
             ros2 launch rmf_demos_gz office.launch.xml headless:=0"
```

### rocker flag reference

| Flag        | Purpose                                                          |
|-------------|------------------------------------------------------------------|
| `--x11`     | Forwards the host X server into the container automatically      |
| `--nvidia`  | Injects NVIDIA driver libraries and GLX support for GPU rendering|
| `--user`    | Runs the container as your host UID/GID (avoids root-owned files)|
| `--volume`  | Mounts a host directory into the container                       |

---

## Notes & troubleshooting

- **rocker builds a temporary derived image** on top of the one you pass in;
  your original image (e.g. `rmf-site-editor:lyrical`) is never modified.
- `docker-compose.yaml` has **no** `site-editor` service and **no** X11 wiring
  on `rmf` — both are launched manually via rocker only when a GUI is actually
  needed.
- **`rmf` image patches** `rmf_visualization_schedule`'s
  `visualization.launch.xml` to set `respawn="true" respawn_delay="2"` on the
  `schedule_visualizer_node`. This is a workaround for upstream segfaults
  ([open-rmf/rmf#546](https://github.com/open-rmf/rmf/issues/546),
  [open-rmf/rmf#637](https://github.com/open-rmf/rmf/issues/637)). The patch
  lives in the **base** (`Dockerfile.rmf`) because `rmf_visualization` is
  built from `rmf.repos`, not `rmf-sim.repos`.
- **Dashboard build pins** specific versions of `react`, `react-dom`, and
  `react-router` via `pnpm.overrides` in `Dockerfile.rmf-web-dashboard`. If you upgrade
  `rmf-web`, re-check that those overrides are still needed.
- **API server pins** for `pydantic` and `asyncpg` are intentionally relaxed
  to `>=` in `Dockerfile.rmf-api-server`. Keep an eye on this if you bump
  `rmf-web`.
