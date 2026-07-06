# Open-RMF — compiled images for ease of use

Pre-built, ready-to-run Docker images for the [Open-RMF](https://www.openrmf.org/)
ecosystem: the ROS 2 simulation/fleet adapter stack, the REST API server, the web
dashboard, and the RMF Site Editor.

> Pick the branch that matches your ROS 2 distribution (e.g. branch `lyrical` for
> ROS 2 `lyrical`). Each branch pins the matching `ROS_DISTRO` build-arg in the
> Dockerfiles.

---

## Table of contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Build](#build)
- [Push to quay.io](#push-to-quayio)
- [Run](#run)
- [Accessing the services](#accessing-the-services)
- [Stop / tear down](#stop--tear-down)
- [Updating / rebuilding a single service](#updating--rebuilding-a-single-service)
- [Running GUI tools via `rocker`](#running-gui-tools-via-rocker)
  - [RMF Site Editor](#rmf-site-editor)
  - [Debugging Gazebo / RViz](#debugging-gazebo--rviz)
- [Repo layout](#repo-layout)
- [Notes & troubleshooting](#notes--troubleshooting)

---

## Architecture

Four services come up under `docker-compose`. The first three are backend, the
fourth is the web UI. All run **headless**; GUIs are launched separately on the
host via `rocker` (see below).

| Service          | Image built from                | Image tag                                                | Role                                                                                |
|------------------|---------------------------------|----------------------------------------------------------|-------------------------------------------------------------------------------------|
| `rmf`            | `docker/Dockerfile.rmf`         | `quay.io/nexsoss/open-rmf:lyrical-rmf`                   | ROS 2 + RMF + `rmf_demos` + fleet adapter + Gazebo server + schedule visualizer     |
| `zenoh-router`   | `eclipse/zenoh:1.9.0-...`       | `eclipse/zenoh:1.9.0-47-g55263c9da`                      | DDS/RMW bridge that connects the in-container ROS 2 graph to the api-server         |
| `api-server`     | `docker/Dockerfile.api-server`  | `quay.io/nexsoss/open-rmf:lyrical-api-server`            | `rmf-web` REST API server, exposes RMF tasks/fleets/dispenser state over HTTP       |
| `rmf-web`        | `docker/Dockerfile.dashboard`   | `quay.io/nexsoss/open-rmf:lyrical-rmf-web-dashboard`    | Nginx-served static build of the `rmf-dashboard-framework` demo dashboard           |
| `rmf-site-editor`(GUI) | `docker/Dockerfile.site-editor` | `quay.io/nexsoss/open-rmf:rmf-site-editor`                      | Rust/Bevy native desktop editor; build-only, launched via `rocker` (not in compose) |

The `image:` keys in `docker-compose.yaml` set the tag for every service that
has a `build:` block, so `docker compose build` tags the result with the
`quay.io/nexsoss/open-rmf:lyrical-*` name automatically (no separate `docker
tag` step needed).

A shared `./maps` directory is mounted into `rmf` so that maps authored in the
Site Editor (also written into `./maps`) are visible to the simulator without
any manual copying.

---

## Prerequisites

On the host machine:

- **Docker** ≥ 20.10 with the Compose plugin (`docker compose ...`) **or**
  Docker Compose v1 (`docker-compose ...`). The commands below use the v2
  `docker compose` form.
- **Git** (only needed if you cloned this repo).
- ~15 GB of free disk space — the `rmf` and `api-server` images pull and build
  the full RMF source tree.
- For GUI tools (`rocker` flow), also see the
  [Running GUI tools via rocker](#running-gui-tools-via-rocker) section.
- For NVIDIA GPU acceleration inside the containers, install the
  [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
  on the host. The compose file does not pin GPU access; rocker injects it
  only for the manually-launched GUI containers.

Clone the repo and switch to the branch matching your ROS distro:

```bash
git clone https://github.com/nexsoss/Open-RMF.git
cd Open-RMF
git checkout lyrical   # or whichever ROS 2 distro branch you need
```

---

## Build

The whole stack is one command. `docker compose build` (or `compose up --build`
on first run) builds each image in dependency order:

```bash
docker compose build
```

To build only a subset:

```bash
docker compose build rmf           # just the RMF sim / fleet adapter image
docker compose build api-server    # just the REST API image
docker compose build rmf-web       # just the dashboard image
```

The `zenoh-router` service pulls a prebuilt image — it has no `build:` block
and is not compiled locally.

> **Time & cache:** the first build of the `rmf` image is the heaviest —
> it compiles all of `rmf_traffic`, `rmf_fleet_adapter`, `rmf_demos`, etc.
> Subsequent builds are fast as long as you don't change `Dockerfile.rmf`.

### Build args

`Dockerfile.rmf` and `Dockerfile.api-server` accept a `ROS_DISTRO` build-arg
(default `lyrical`). Override it either in `docker-compose.yaml` (the `rmf`
service already pins `ROS_DISTRO: lyrical`) or directly:

```bash
docker build --build-arg ROS_DISTRO=lyrical -f docker/Dockerfile.rmf -t rmf-sim:lyrical .
```

---

## Run

Bring the whole stack up in the background:

```bash
docker compose up -d
```

This starts `rmf` → `zenoh-router` → `api-server` → `rmf-web` in the correct
order (Compose `depends_on`) and tails logs.

To watch logs:

```bash
docker compose logs -f               # all services
docker compose logs -f rmf           # just the RMF sim
docker compose logs -f api-server    # just the API
```

To run attached (Ctrl-C to stop):

```bash
docker compose up
```

---

## Accessing the services

| Service          | URL (from the host)                                | Notes                                              |
|------------------|----------------------------------------------------|----------------------------------------------------|
| `rmf-web`        | http://localhost:3000                              | Open-RMF web dashboard                             |
| `api-server`     | http://localhost:8080                              | REST API (FastAPI / uvicorn)                       |
| `api-server`     | ws://localhost:8080                                | WebSocket for live RMF state                       |
| `rmf`            | (internal only — no published port)                | ROS 2 graph reachable through the bridge            |
| `zenoh-router`   | (internal only — no published port)                | DDS-to-Zenoh router                                |

The dashboard at `:3000` is the main entry point for operators. It talks to
`api-server` at `:8080`, which in turn talks to the ROS 2 graph inside the
`rmf` container via `zenoh-router`.

---

## Stop / tear down

```bash
docker compose stop            # stop containers, keep them
docker compose down            # stop and remove containers + the network
docker compose down -v         # also drop anonymous volumes (if any)
```

`docker compose down` does **not** delete built images — they remain in the
local Docker image cache for the next `up`.

---

## Updating / rebuilding a single service

After pulling new code or changing a Dockerfile:

```bash
docker compose build api-server && docker compose up -d api-server
```

For the heavy `rmf` image, prefer `--no-cache` only when you actually changed
build dependencies; otherwise the Docker layer cache will reuse the ROS 2
install and just rebuild the RMF packages that changed.

---

## Running GUI tools via `rocker`

GUI applications (RMF Site Editor, and Gazebo/RViz when visually debugging the
simulation) are **not** part of `docker-compose`. They run on the host via
[`rocker`](https://github.com/osrf/rocker), which injects X11 / GPU
configuration at container launch time. Compose stays clean and headless.

### 1. Install rocker (on the host, not inside any container)

```bash
sudo apt-get install python3-rocker
# or
pip install rocker
```

### 2. RMF Site Editor

The site-editor image is published as `quay.io/nexsoss/open-rmf:rmf-site-editor`.
You can either pull the published image (recommended — no Rust toolchain
needed) or build it locally.

**Pull from quay.io and launch:**

```bash
docker pull quay.io/nexsoss/open-rmf:rmf-site-editor

# Without an NVIDIA GPU:
rocker --x11 --user --volume ./maps:/root/site_maps \
    -- quay.io/nexsoss/open-rmf:rmf-site-editor

# With an NVIDIA GPU (recommended — hardware-accelerated rendering):
rocker --nvidia --x11 --user --volume ./maps:/root/site_maps \
    -- quay.io/nexsoss/open-rmf:rmf-site-editor
```

**Or build locally** (tag it with the quay tag so the build & push command is
the same):

```bash
docker build -f docker/Dockerfile.site-editor \
    -t quay.io/nexsoss/open-rmf:rmf-site-editor .

# Then launch with rocker using the same image reference as above:
rocker --x11 --user --volume ./maps:/root/site_maps \
    -- quay.io/nexsoss/open-rmf:rmf-site-editor
```

Exported map files (`.building.yaml` / SDF) land in `./maps` on the host,
which is the same directory mounted into the `rmf` service in
`docker-compose.yaml` — no manual copying needed between the two.

### 3. Debugging Gazebo / RViz

`rmf` runs headless by default under compose. To visually debug Gazebo or RViz,
launch the same image manually via rocker instead of changing anything in
`docker-compose.yaml`. Use the published `quay.io` image:

```bash
docker pull quay.io/nexsoss/open-rmf:lyrical-rmf

rocker --nvidia --x11 --user \
    --volume ./maps:/home/ws_rmf/install/rmf_demos_maps/share/rmf_demos_maps/maps \
    -- quay.io/nexsoss/open-rmf:lyrical-rmf \
    bash -c "source /opt/ros/lyrical/setup.bash && \
             source /home/ws_rmf/install/setup.bash && \
             ros2 launch rmf_demos_gz office.launch.xml headless:=0"
```

Or build the image locally with `docker compose build rmf` (which tags it
`quay.io/nexsoss/open-rmf:lyrical-rmf` automatically) and use the same image
reference above.

### rocker flag reference

| Flag        | Purpose                                                          |
|-------------|------------------------------------------------------------------|
| `--x11`     | Forwards the host X server into the container automatically      |
| `--nvidia`  | Injects NVIDIA driver libraries and GLX support for GPU rendering|
| `--user`    | Runs the container as your host UID/GID (avoids root-owned files)|
| `--volume`  | Mounts a host directory into the container                       |

---

## Repo layout

```
.
├── README.md                       this file
├── docker-compose.yaml             backend stack (rmf, zenoh-router, api-server, rmf-web)
├── docker/
│   ├── Dockerfile.rmf              ROS 2 + RMF + rmf_demos + fleet adapter
│   ├── Dockerfile.api-server       rmf-web REST API (FastAPI/uvicorn)
│   ├── Dockerfile.dashboard        rmf-dashboard-framework demo build, served by nginx
│   ├── Dockerfile.site-editor      rmf_site (Rust/Bevy) native desktop binary
│   └── nginx.conf                  nginx site config for the dashboard image
└── maps/                           shared map directory (mounted into rmf; written by Site Editor)
```

---

## Notes & troubleshooting

- **rocker builds a temporary derived image** on top of the one you pass in;
  your original image (e.g. `rmf-site-editor:lyrical`) is never modified.
- `docker-compose.yaml` has **no** `site-editor` service and **no** X11 wiring
  on `rmf` — both are launched manually via rocker only when a GUI is actually
  needed.
- The web-hosted WASM build of the Site Editor
  (https://open-rmf.github.io/rmf_site/) is available with zero setup for quick
  viewing/demos, but it currently lacks map save/load support, so use the
  native desktop build above for real editing work.
- **`rmf` image patches** `rmf_visualization_schedule`'s
  `visualization.launch.xml` to set `respawn="true" respawn_delay="2"` on the
  `schedule_visualizer_node`. This is a workaround for upstream segfaults
  ([open-rmf/rmf#546](https://github.com/open-rmf/rmf/issues/546),
  [open-rmf/rmf#637](https://github.com/open-rmf/rmf/issues/637)).
- **Dashboard build pins** specific versions of `react`, `react-dom`, and
  `react-router` via `pnpm.overrides` in `Dockerfile.dashboard`. If you upgrade
  `rmf-web`, re-check that those overrides are still needed.
- **API server pins** for `pydantic` and `asyncpg` are intentionally relaxed
  to `>=` in `Dockerfile.api-server`. Keep an eye on this if you bump
  `rmf-web`.