cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "sqlcipher_flutter_libs")
project(${PROJECT_NAME} LANGUAGES C CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "sqlcipher_flutter_libs_plugin")

# Essentially, the idea of this build script is to compile a sqlite3.dll
# and make Fluter bundle that with the final app.
# It looks like we can't avoid building a sqlite3_flutter_libs.dll too,
# but that's not on me.

add_library(${PLUGIN_NAME} SHARED
  "sqlite3_flutter_libs_plugin.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)


set(OPENSSL_USE_STATIC_LIBS TRUE)
find_package(OpenSSL REQUIRED)

# Using a prebuilt sqlcipher amalgation because building it requires TCL/TK which no one has.
file(DOWNLOAD "https://storage.googleapis.com/simon-public-euw3/assets/sqlcipher/v4_5_7.c" "${CMAKE_CURRENT_BINARY_DIR}/sqlcipher.c" EXPECTED_HASH SHA512=11bb454d761b994f7e44f35dabd3fc8ac3b40499d6fdc29d58a38fb9b4dcdd6eb14ff3978ceb7c6f3bd5eee4a5abeec5f0453b944268f9aaf942b0366df1e73d)

add_library(sqlite3 SHARED "sqlite3_flutter.c")
target_include_directories(sqlite3 PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_compile_options(${PLUGIN_NAME} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
set_property(SOURCE "sqlite3_flutter.c" APPEND PROPERTY OBJECT_DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/sqlcipher.c")
target_link_libraries(sqlite3 PRIVATE OpenSSL::Crypto)

# Note: Keep in sync with https://github.com/simolus3/sqlite-native-libraries/blob/master/sqlite3-native-library/cpp/CMakeLists.txt
# SQLITE_HAS_CODEC is required for sqlcipher
target_compile_definitions(sqlite3 PRIVATE
  SQLITE_HAS_CODEC
  SQLITE_DQS=0
  SQLITE_THREADSAFE=1
  SQLITE_DEFAULT_MEMSTATUS=0
  SQLITE_TEMP_STORE=2
  SQLITE_MAX_EXPR_DEPTH=0
  SQLITE_OMIT_AUTHORIZATION
  SQLITE_OMIT_DECLTYPE
  SQLITE_OMIT_DEPRECATED
  SQLITE_OMIT_PROGRESS_CALLBACK
  SQLITE_OMIT_SHARED_CACHE
  SQLITE_OMIT_TCL_VARIABLE
  SQLITE_OMIT_TRACE
  SQLITE_USE_ALLOCA
  SQLITE_UNTESTABLE
  SQLITE_HAVE_ISNAN
  SQLITE_ENABLE_DBSTAT_VTAB
  SQLITE_ENABLE_FTS5
  SQLITE_ENABLE_JSON1
  SQLITE_ENABLE_RTREE
)

# Ensure sqlite3 actually gets build
add_dependencies(${PLUGIN_NAME} sqlite3)

# List of absolute paths to libraries that should be bundled with the plugin
set(sqlcipher_flutter_libs_bundled_libraries
  "$<TARGET_FILE:sqlite3>"
  PARENT_SCOPE
)
