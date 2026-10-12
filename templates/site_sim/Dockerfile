# Builds a site package (default: ./example_site) on top of the sim-site image,
# which already carries rmf_site_editor, rmf_site_cmake and the rmf_demos sim
# stack. The site's world and nav graphs are generated at build time.
ARG SIM_SITE_IMAGE=quay.io/nexsoss/open-rmf:lyrical_sim-site
FROM ${SIM_SITE_IMAGE}

ARG SITE_PACKAGE=example_site

WORKDIR /home/ws_rmf
COPY ${SITE_PACKAGE} src_sites/${SITE_PACKAGE}

RUN /bin/bash -c "source /home/ws_rmf/install/setup.bash && \
    colcon build --base-paths src_sites --packages-select ${SITE_PACKAGE}"

# rmf_site_editor exits 0 even when an export fails, leaving a 0-byte .world.
# Fail the build instead of shipping an image whose simulator cannot load its
# world.
RUN /bin/bash -c 'set -eo pipefail; \
    share=/home/ws_rmf/install/${SITE_PACKAGE}/share/${SITE_PACKAGE}/maps; \
    found=0; \
    for w in "$share"/*/*.world; do \
      found=1; \
      test -s "$w" || { echo "FATAL: empty world $w -- see templates/site_sim/README.md (textures)"; exit 1; }; \
      d=$(dirname "$w"); \
      ls "$d"/nav_graphs/*.nav.yaml >/dev/null 2>&1 || { echo "FATAL: no nav graphs in $d"; exit 1; }; \
    done; \
    test "$found" = 1 || { echo "FATAL: no worlds generated under $share"; exit 1; }'

ENV RMW_IMPLEMENTATION=rmw_zenoh_cpp
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
