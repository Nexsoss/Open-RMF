# rmf_site patches

`rmf_site_exporter_fixes.patch` is applied to `open-rmf/rmf_site` at
`RMF_SITE_REF` in the builder stage of both `Dockerfile.rmf-sim-site` and
`Dockerfile.site-editor`. Both images embed the same `rmf_site_editor` binary,
so both must carry it.

## What it fixes

`RMF_SITE_REF` is the commit `rmf_site_editor` 0.0.3, the current crates.io
release, was published from, so the images match `cargo install
rmf_site_editor`. The patch adds three exporter fixes:

| file | defect |
|---|---|
| `rmf_site_editor/src/site/headless_export.rs` | Headless export (`--export-sdf`) waited for models but not for textures, which load asynchronously. With `Remote` textures it failed with `Unable to collect site meshes: Texture not found`, wrote an empty `.world`, and still exited 0. It now waits until every texture has loaded or failed. |
| `rmf_site_editor/src/site/sdf_exporter.rs` | A lift cabin door without door segments was skipped silently while the SDF still referenced its meshes, so Gazebo failed to load the world. It is now an export error. |
| `rmf_site_format/src/legacy/nav_graph.rs` | A lift cabin waypoint is emitted on every level, ignoring which levels the lift serves, so the planner can route a lift to floors it cannot reach. |

Later upstream versions need two more fixes (cabin-door meshes and
per-level wall heights) for code that 0.0.3 does not have yet. Add them
back when moving the pin past 0.0.3.

## Why the ref is pinned

An unpinned clone changes the generated world and nav graph whenever upstream
moves, and the patch cannot be guaranteed to apply to a moving HEAD. `git
apply` is deliberately not `|| true`: a patch that stops applying fails the
build.

## Maintenance

Bump `RMF_SITE_REF` and refresh the patch together. As each fix lands
upstream, drop it from the patch; when the patch is empty, remove the
`COPY`/`git apply` lines and keep the pin.
