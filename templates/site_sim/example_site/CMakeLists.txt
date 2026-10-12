cmake_minimum_required(VERSION 3.8)
project(example_site)

find_package(ament_cmake REQUIRED)
find_package(rmf_site_cmake REQUIRED)

# Every maps/<name>/<name>.site.json becomes
#   share/example_site/maps/<name>/<name>.world
#   share/example_site/maps/<name>/nav_graphs/<graph>.nav.yaml
# by running `rmf_site_editor --export-sdf --export-nav` at build time.
rmf_site_generate_map_package(
  INPUT_MAP_DIR maps
  OUTPUT_PACKAGE_DIR ${CMAKE_CURRENT_BINARY_DIR}/maps
)

install(DIRECTORY launch config maps
  DESTINATION share/${PROJECT_NAME}
)
install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/maps
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
