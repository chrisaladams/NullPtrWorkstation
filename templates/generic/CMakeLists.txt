cmake_minimum_required(VERSION 3.20)
project(__NAME__ LANGUAGES C)

# This file is yours: nothing edits it for you.
# New source files must be added to add_executable() below.

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "Debug or Release" FORCE)
endif()
set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)   # for clangd (code completion in AstroVim)

add_executable(${PROJECT_NAME}
  src/main.c
)
target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra
  $<$<CONFIG:Debug>:-g3 -O0>
  $<$<CONFIG:Release>:-O2>)

# Using a library? With pkg-config:
#   find_package(PkgConfig REQUIRED)
#   pkg_check_modules(SDL2 REQUIRED IMPORTED_TARGET sdl2)
#   target_link_libraries(${PROJECT_NAME} PRIVATE PkgConfig::SDL2)
# The math library:
#   target_link_libraries(${PROJECT_NAME} PRIVATE m)
