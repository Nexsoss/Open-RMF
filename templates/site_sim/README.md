# Template: your own site, simulated with tinyRobot

A starting point for running Open-RMF on **your own map**: author the site in
the [RMF Site Editor](https://github.com/open-rmf/rmf_site), drop it into this
package, and run it in Gazebo with one or more `tinyRobot`s, together with the
API server and web dashboard from this repository.

```
templates/site_sim/
├── Dockerfile                    # builds your package on top of open-rmf:lyrical_sim-site
├── compose.override.yaml         # runs your build as the stack's rmf-sim
├── TUTORIAL.md                   # step by step: floorplan PNG -> site -> robots running
├── docs/                         # screenshots for the tutorial
└── example_site/                 # a finished site package; add yours next to it
    ├── CMakeLists.txt            # .site.json -> .world + nav graphs, at build time
    ├── package.xml
    ├── maps/example_site/example_site.site.json
    ├── maps/example_site/example_site.png
    ├── config/example_site/tinyRobot_config.yaml
    └── launch/example_site.launch.xml
```

The example site is a 20 m × 12 m room with a floorplan image (shown in the
dashboard), six named places (`lobby`, `pantry`, `store`, `office_a`,
`office_b`, `meeting`) on a loop, two chargers and two tinyRobots.

## 1. Run the example

`example_site` is the default world of the main stack, already built into
`open-rmf:lyrical_sim`. From the repository root:

```bash
docker compose up -d
```

Then open the dashboard at http://localhost:3000, or send a task from the
command line:

```bash
docker exec -it rmf-sim bash -c 'source /home/ws_rmf/install/setup.bash && \
  ros2 run rmf_demos_tasks dispatch_patrol -p office_a meeting -n 2 --use_sim_time'
```

To watch Gazebo instead of running headless, see
[RMF, Gazebo and RViz, one terminal each](../../README.md#rmf-gazebo-and-rviz-one-terminal-each)
in the main README.

## 2. Make it your site

**Follow [TUTORIAL.md](TUTORIAL.md).** It walks through every click: loading
a floorplan PNG and scaling it, drawing walls, a floor, lanes and named
waypoints, tagging chargers, adding TinyRobots (including the **Robot**
properties without which they never move), writing the fleet config, and
building and running the result. It creates a new package, `tutorial_site`,
from the same floorplan, so `example_site` doubles as the answer key.

In short, to make a site called `tutorial_site`, next to `example_site`:

1. Create `tutorial_site/maps/tutorial_site/` and author
   `tutorial_site.site.json` there in the Site Editor, with the floorplan image
   next to it.
2. Add the supporting files, copied from `example_site` with the name changed:
   `package.xml`, `CMakeLists.txt`, `launch/tutorial_site.launch.xml` and
   `config/tutorial_site/tinyRobot_config.yaml`.
3. List the robots in the fleet config. Each name must match a robot in the
   site, and each `charger` must be a location tagged Charger.
4. Build and run:

   ```bash
   export SITE_PACKAGE=tutorial_site
   docker compose -f docker-compose.yaml -f templates/site_sim/compose.override.yaml build rmf-sim
   docker compose -f docker-compose.yaml -f templates/site_sim/compose.override.yaml up -d
   ```

Packages you add here are ignored by git, so your own sites stay out of this
repository. In a fork where you do want to commit one, add a matching
`!templates/site_sim/<name>/` line to `.gitignore`.

## Rules worth knowing

- **The dashboard map shows the site's floorplan drawing.** Without one the
  map is blank. The map server reads it relative to the `.site.json`, so keep
  the image next to it. Only the first drawing per level is shown.

- **One nav graph file per graph.** The graph named `tinyRobot` is exported as
  `nav_graphs/tinyRobot.nav.yaml`. If you rename the graph, or add a second
  fleet, update the launch file (one fleet-adapter `<group>` per fleet, each
  with its own config).
- **Empty worlds fail the build.** The Site Editor's headless export can
  write an empty `.world` and still report success, so the Dockerfile checks
  every generated world. (Images built from this repository carry an editor
  fix for the most common cause, `Remote` wall/floor textures.)
- **Furniture models must have loadable meshes.** Static models (furniture
  etc.) are baked into the world's meshes at build time, so the simulator
  needs no internet access. A *non-static* model whose mesh the editor cannot
  load (Fuel `.dae` models such as `OpenRobotics/Coke`) is exported as an
  empty collision mesh, and Gazebo aborts on start with
  `ODE INTERNAL ERROR 1: assertion "vertices" failed`. Mark such models
  static, or leave them out.
- Authoring is done in the RMF Site Editor only. Traffic-editor
  `.building.yaml` files are not used by this template.
