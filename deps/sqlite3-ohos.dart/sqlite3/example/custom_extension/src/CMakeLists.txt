# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(uuid_library VERSION 0.0.1 LANGUAGES C)

add_library(uuid SHARED
  "uuid.c"
)

set_target_properties(uuid PROPERTIES
  OUTPUT_NAME "uuid"
)

target_compile_definitions(uuid PUBLIC DART_SHARED_LIB)
