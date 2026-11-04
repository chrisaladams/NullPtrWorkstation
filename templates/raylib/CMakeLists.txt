cmake_minimum_required(VERSION 3.20)
project(__NAME__ LANGUAGES C)

# Debug is the default: symbols (-g3), no optimisation, works with GDB / nvim-dap.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "Debug or Release" FORCE)
endif()
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)   # clangd reads compile_commands.json

find_package(PkgConfig REQUIRED)
pkg_check_modules(RAYLIB REQUIRED IMPORTED_TARGET raylib>=5.0)

add_executable(${PROJECT_NAME} src/main.c)
target_link_libraries(${PROJECT_NAME} PRIVATE PkgConfig::RAYLIB m)
target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra
  $<$<CONFIG:Debug>:-g3 -O0>
  $<$<CONFIG:Release>:-O2>)
# Assets are loaded relative to the project root (run-game starts the game there).
target_compile_definitions(${PROJECT_NAME} PRIVATE ASSETS_DIR="assets/")
