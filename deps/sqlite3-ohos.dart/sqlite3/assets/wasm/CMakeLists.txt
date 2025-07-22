cmake_minimum_required(VERSION 3.24)

set(PROJECT_NAME "sqlite3_web")
project(${PROJECT_NAME} LANGUAGES C)

set(triple wasm32-unknown-wasi)
set(wasi_sysroot "/usr/share/wasi-sysroot" CACHE PATH "Path to wasi sysroot")
set(clang "clang" CACHE FILEPATH "Path to wasm-capable clang executable")

include(FetchContent)

FetchContent_Declare(
    sqlite3
    # NOTE: When changing this, also update `test/wasm/sqlite3_test.dart`
    URL https://sqlite.org/2024/sqlite-autoconf-3460000.tar.gz
    DOWNLOAD_EXTRACT_TIMESTAMP NEW
)

FetchContent_MakeAvailable(sqlite3)

file(DOWNLOAD https://raw.githubusercontent.com/sqlite/sqlite/master/src/test_vfstrace.c "${CMAKE_BINARY_DIR}/vfstrace.c")

# Generate symbols we need to export from the sqlite3.wasm build
add_custom_command(
    OUTPUT required_symbols.txt
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../../
    COMMAND dart run tool/wasm_symbols.dart ${CMAKE_CURRENT_BINARY_DIR}/required_symbols.txt
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../../tool/wasm_symbols.dart
    VERBATIM
)
add_custom_target(required_symbols DEPENDS required_symbols.txt)

macro(base_sqlite3_target name debug)
  set(clang_output ${name}.clang.wasm)
  set(init_output ${name}.init.wasm)
  set(output ${init_output})

  set(sources
    ${CMAKE_CURRENT_SOURCE_DIR}/os_web.c
    ${CMAKE_CURRENT_SOURCE_DIR}/helpers.c
    ${sqlite3_SOURCE_DIR}/sqlite3.c
  )
  set(flags -Wall -Wextra -Wno-unused-parameter -Wno-unused-function)

  if(${debug})
    list(APPEND sources "${CMAKE_BINARY_DIR}/vfstrace.c")
    list(APPEND flags "-g" "-DDEBUG")
  else()
    list(APPEND flags "-Oz" "-DNDEBUG" "-flto")
  endif()

  add_custom_command(
    OUTPUT ${clang_output}
    COMMAND ${clang} --target=${triple} -std=c23
      ${flags}
      -o ${clang_output}
      -I ${PROJECT_SOURCE_DIR} -I ${sqlite3_SOURCE_DIR}
      -D_HAVE_SQLITE_CONFIG_H
      -mcpu=generic
      -mexec-model=reactor
      -fno-stack-protector -fno-stack-clash-protection
      -Wl,--import-memory
      --sysroot ${wasi_sysroot}
      ${sources}
      @${CMAKE_CURRENT_BINARY_DIR}/required_symbols.txt
    DEPENDS ${sources} required_symbols
    VERBATIM
  )

  add_custom_command(
    OUTPUT ${init_output}
    COMMAND wasm-ctor-eval -c _initialize ${clang_output} -o ${init_output}
    VERBATIM
    DEPENDS ${clang_output}
  )

  if(NOT ${debug})
    set(output ${name}.wasm)

    add_custom_command(
        OUTPUT ${output}
        COMMAND wasm-opt --strip --strip-producers -c -O4 ${init_output} -o ${output}
        VERBATIM
        DEPENDS ${init_output}
    )
  endif()

  add_custom_target(${name} DEPENDS ${output})
endmacro()

base_sqlite3_target(sqlite3_debug true)
base_sqlite3_target(sqlite3_opt false)

add_custom_target(output)
add_custom_command(TARGET output COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/sqlite3_opt.wasm ${PROJECT_SOURCE_DIR}/../../example/web/sqlite3.wasm)
add_custom_command(TARGET output COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/sqlite3_debug.init.wasm ${PROJECT_SOURCE_DIR}/../../example/web/sqlite3.debug.wasm)
add_dependencies(output sqlite3_debug sqlite3_opt)
