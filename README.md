# Open-RMF — compiled images for ease of use
> Open-source project, maintained and supported by [Nexsoss](https://nexsoss.ai).
> Licensed under Apache-2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

Pre-built, ready-to-run Docker images for the [Open-RMF](https://www.openrmf.org/)
ecosystem: the ROS 2 simulation/fleet adapter stack, the REST API server, the web
dashboard, and the RMF Site Editor.

Pick the branch that matches your ROS 2 distribution (e.g. branch `lyrical` for ROS 2 `lyrical`). Each branch pins the matching `ROS_DISTRO` build-arg in the Dockerfiles.

Tested images are published to `quay.io/nexsoss/open-rmf:<tag>`; nightly builds of the branch go to `ghcr.io/nexsoss/open-rmf:nightly_<tag>`.

**Want your own map?** Follow the [step-by-step tutorial](templates/site_sim/TUTORIAL.md): take a floorplan PNG, draw walls, lanes and waypoints in the RMF Site Editor, add tinyRobots, and run it all in simulation. The [site template](templates/site_sim/README.md) has the package it builds on.

---

## Table of contents

- [Prerequisites](#prerequisites)
- [Build](#build)
- [Run](#run)
- [Accessing the services](#accessing-the-services)
- [Stop / tear down](#stop--tear-down)
- [Updating / rebuilding a single service](#updating--rebuilding-a-single-service)
- [RMF Site Editor](#rmf-site-editor)
  - [Option 1: install from crates.io (no container)](#option-1-install-from-cratesio-no-container)
  - [Option 2: run the image with distrobox](#option-2-run-the-image-with-distrobox)
- [Running GUI tools via `distrobox`](#running-gui-tools-via-distrobox)
  - [RMF, Gazebo and RViz, one terminal each](#rmf-gazebo-and-rviz-one-terminal-each)
- [Your own site: the template](templates/site_sim/README.md)
- [Notes & troubleshooting](#notes--troubleshooting)

---

Images are layered. `Dockerfile.rmf` is a **shared base** that compiles the core RMF packages from `repos/rmf.repos`. `Dockerfile.rmf-sim` and `Dockerfile.rmf-api-server` both derive from that base — they add only the apt/pip packages and build steps specific to their role. GUI/Qt/GL/X11/Gazebo packages and `flask-socketio` live in `rmf-sim` only; the api-server image is slimmer and has no GUI dependencies.

Four services come up under `docker compose`: `zenoh-router`, `rmf-api-server` and `rmf-sim` are the backend, `rmf-web-dashboard` is the web UI. All run **headless**. GUIs run separately: the Site Editor natively or via `distrobox`, Gazebo and RViz via `distrobox` (see below).

| Service          | Image built from                | Role                                                                                |
|------------------|---------------------------------|-------------------------------------------------------------------------------------|
| `rmf-base`       | `docker/Dockerfile.rmf`         | Shared base: ROS 2 + RMF core packages from `rmf.repos`. Build-only; never runs.     |
| `rmf-sim`        | `docker/Dockerfile.rmf-sim`     | Base + Gazebo + `rmf_demos`/`rmf_simulation` from `rmf-sim.repos`; runs the [example site](templates/site_sim/README.md) with two tinyRobots |
| `rmf-sim-site`   | `docker/Dockerfile.rmf-sim-site` | `rmf-sim` + RMF Site Editor + `rmf_site_ros2`, for building sites from `.site.json`. Build-only (`--profile build`). |
| `zenoh-router`   | `docker/Dockerfile.rmf` (base)  | `rmw_zenohd`, the router shipped with `rmw_zenoh` (same zenoh revision as the RMF nodes) |
| `rmf-api-server` | `docker/Dockerfile.rmf-api-server` | `rmf-web` API server       |
| `rmf-web-dashboard` | `docker/Dockerfile.rmf-web-dashboard` | Static build of the `rmf-dashboard-framework` demo dashboard           |
| (GUI) site editor | `docker/Dockerfile.site-editor` | RMF Site Editor desktop; not a compose service. Install it from crates.io or run this image via `distrobox` ([RMF Site Editor](#rmf-site-editor)) |


Simulated worlds are generated from [RMF Site Editor](https://github.com/open-rmf/rmf_site) `.site.json` files when the image is built; traffic-editor `.building.yaml` maps (and the `rmf_demos` worlds made from them) are not used. The default world is the [site template](templates/site_sim/README.md)'s `example_site`; set `SITE_PACKAGE` to run another site package baked into the image.

---

## Prerequisites

On the host machine:

- **Docker**, Compose plugin (`docker compose ...`)
- ~15 GB of free disk space 
- For the Site Editor: either Rust (to install it from crates.io) or distrobox, see [RMF Site Editor](#rmf-site-editor).
- For watching Gazebo and RViz: [distrobox](https://distrobox.it/), see [Running GUI tools via distrobox](#running-gui-tools-via-distrobox).
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
docker compose -f docker-compose.local.yaml build rmf-base    # build the shared base explicitly (recommended)
docker compose -f docker-compose.local.yaml build             # then build the rest
```

To build only a subset:

```bash
docker compose -f docker-compose.local.yaml build rmf-sim        # just the RMF sim / fleet adapter image
docker compose -f docker-compose.local.yaml build rmf-api-server # just the REST API image
docker compose -f docker-compose.local.yaml build rmf-web-dashboard  # just the dashboard image
```

The `zenoh-router` service runs from the base image (`rmf-base`), so build that first.

## Run

Bring the whole stack up in the background:

```bash
docker compose -f docker-compose.local.yaml up -d
```

OR, if you want to use pre-built images -
```bash
docker compose up -d
```

This starts `zenoh-router` → `rmf-api-server` → `rmf-sim` and `rmf-web-dashboard`, each waiting for its dependencies to be healthy.

To watch logs:

```bash
docker compose logs -f               # all services
docker compose logs -f rmf-sim       # just the RMF sim
```
---

## Accessing the services

| Service          | URL (from the host)                                | Notes                                              |
|------------------|----------------------------------------------------|----------------------------------------------------|
| `rmf-web-dashboard` | http://localhost:3000                           | Open-RMF web dashboard                             |
| `rmf-api-server` | http://localhost:8000                              | REST API and socket.io live updates (docs at `/docs`) |
| `rmf-api-server` | ws://localhost:8000/_internal                      | Fleet adapters / RMF nodes report state here       |
| `zenoh-router`   | (internal only — no published port)                | Zenoh router                                       |

---

## Stop / tear down

```bash
docker compose down            # stop and remove containers + the network
```

---

## RMF Site Editor

The [RMF Site Editor](https://github.com/open-rmf/rmf_site) is the desktop
app for drawing sites (`.site.json`): floorplan, walls, lanes, waypoints and
robots. This repository uses **version 0.0.3**, the current crates.io
release, and the images build that same version. To turn a site into a
simulated world with robots, follow the
[tutorial](templates/site_sim/TUTORIAL.md).

Keep your sites anywhere in your home directory, e.g. this repository's
`maps/` (gitignored).

### Option 1: install from crates.io (no container)

On Ubuntu, install the build dependencies and Rust (via
[rustup](https://rustup.rs); the distro's `rustc` may be too old), then the
editor:

```bash
sudo apt install build-essential pkg-config curl libgtk-3-dev libasound2-dev libudev-dev
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh   # accept the defaults
. "$HOME/.cargo/env"                                              # or open a new terminal
cargo install rmf_site_editor --version 0.0.3 --locked
```

The build takes 5–15 minutes. It installs `~/.cargo/bin/rmf_site_editor`,
which you run with:

```bash
rmf_site_editor                      # welcome screen: create or open a site
rmf_site_editor path/to/my_site.site.json
```

- Keep `--version 0.0.3 --locked`: they give exactly the version the
  tutorial and images use, with the dependency versions it was released
  with.
- The editor needs a working Vulkan or OpenGL driver; a normal desktop
  install has one. On other systems, see the
  [rmf_site README](https://github.com/open-rmf/rmf_site).

### Option 2: run the image with distrobox

No Rust toolchain needed. Install distrobox first (see
[Running GUI tools via distrobox](#running-gui-tools-via-distrobox)), then:

```bash
distrobox create --name rmf-site-editor --image quay.io/nexsoss/open-rmf:rmf-site-editor   # once
distrobox enter rmf-site-editor -- /usr/local/bin/rmf_site_editor
```

- The box shares your home directory, so the editor's dialogs show your
  own files.
- Use the **full path** `/usr/local/bin/rmf_site_editor`. If you also did
  option 1, a plain `rmf_site_editor` would run the `~/.cargo/bin` copy.
- To use an image built from this repository instead, build it with
  `docker build -f docker/Dockerfile.site-editor -t localhost/open-rmf:rmf-site-editor .`
  and pass `--image localhost/open-rmf:rmf-site-editor`.

The image also carries a few exporter fixes for world generation (see
[docker/patches/](docker/patches/README.md)). They only affect the headless
export the image builds run, so sites drawn with either option are the same.

---

## Running GUI tools via `distrobox`

GUI applications (Gazebo and RViz when you want to watch the simulation, and
optionally the RMF Site Editor) are not compose services; compose stays
headless. Run them with [distrobox](https://distrobox.it/), a long-lived
container that is integrated with your desktop:

- it runs as **you**, so files it creates are owned by you;
- it shares your **home directory**, display (X11 or Wayland), GPU, network
  and process table, so no volume, display or network flags are needed;
- the image's own files (`/home/ws_rmf`, `/opt/ros`, `/usr/local/bin`) are
  still the container's.

You create a box once, then open as many terminals in it as you like.

**Install** distrobox (it works with docker or podman):
https://distrobox.it/#installation. With an NVIDIA GPU, add `--nvidia` to the
`distrobox create` commands below (it needs the
[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)).
The first `distrobox enter` of a new box takes a minute or so while distrobox
sets up your user inside it.

The Site Editor in a distrobox is option 2 under
[RMF Site Editor](#rmf-site-editor).

### RMF, Gazebo and RViz, one terminal each

Run the API server and dashboard with compose, and RMF and the simulation in
a distrobox made from the sim image. Everything uses the host network, so
they find each other on `localhost`. **Don't** also start the compose
`rmf-sim` service, or you get two copies of every robot.

```bash
# once
distrobox create --name rmf-sim --image quay.io/nexsoss/open-rmf:lyrical_sim
```

**Terminal 1 (host):** zenoh router, API server and dashboard.

```bash
docker compose up -d zenoh-router rmf-api-server rmf-web-dashboard
```

**Terminal 2:** RMF core, the Gazebo server and the tinyRobot fleet adapter.
Start it from a scratch directory: the traffic schedule writes a
`.rmf_schedule_node.yaml` file into the current directory.

```bash
distrobox enter rmf-sim
mkdir -p ~/rmf_run && cd ~/rmf_run
source /home/ws_rmf/install/setup.bash
ros2 launch example_site example_site.launch.xml headless:=true \
    server_uri:=ws://localhost:8000/_internal
```

**Terminal 3:** the Gazebo window. It attaches to the running server.

```bash
distrobox enter rmf-sim
source /home/ws_rmf/install/setup.bash
gz sim -g
```

**Terminal 4:** RViz, showing the RMF schedule, nav graph and robots.

```bash
distrobox enter rmf-sim
source /home/ws_rmf/install/setup.bash
rviz2 -d $(ros2 pkg prefix rmf_visualization_schedule)/share/rmf_visualization_schedule/config/rmf.rviz \
    --ros-args -p use_sim_time:=true
```

**Terminal 5:** send tasks (or use the dashboard at http://localhost:3000).

```bash
distrobox enter rmf-sim
source /home/ws_rmf/install/setup.bash
ros2 run rmf_demos_tasks dispatch_patrol -p office_a meeting -n 1 --use_sim_time
```

To get the Gazebo window and RViz from terminal 2 alone, launch with
`headless:=false` instead.

**Your own site:** build its image with the
[site template](templates/site_sim/README.md), make a distrobox from that
image (e.g. `distrobox create --name my-site --image localhost/open-rmf:lyrical_my_site`),
and launch `my_site my_site.launch.xml` in terminal 2.

**Good to know:**

- Stop with Ctrl-C in each terminal, then `docker compose down`.
- The sim image sets `RMW_IMPLEMENTATION=rmw_zenoh_cpp`, and that carries
  into the distrobox. Your `~/.bashrc` also runs inside it, so if it sources
  a host ROS install, enter with `distrobox enter rmf-sim -- bash --norc`
  instead.
- Gazebo writes to `~/.gz`. If an earlier container run created that
  directory as root, Gazebo logs `Permission denied` there; fix it with
  `sudo chown -R $USER: ~/.gz`.
- Closing the Gazebo window can print `terminate called ... RCLError ...
  context is not valid`. It comes from an RMF GUI plugin during shutdown and
  is harmless.
- After pulling a newer image, recreate the box:
  `distrobox rm rmf-sim`, then `distrobox create` as above.

---

## Notes & troubleshooting

- `docker-compose.yaml` has **no** `site-editor` service and **no** X11 wiring
  on `rmf-sim`. GUIs run via distrobox only when actually needed.
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
