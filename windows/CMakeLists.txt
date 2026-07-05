cmake_minimum_required(VERSION 3.14)
project(copyshelf LANGUAGES CXX)

set(BINARY_NAME "copyshelf")
set(PROJECT_DIR "${CMAKE_SOURCE_DIR}/..")

# Flutter embedder
set(EPHEMERAL_DIR "${PROJECT_DIR}/build/ephemeral/windows")

# Generated plugin registrar
add_subdirectory("${EPHEMERAL_DIR}/.plugin_symlinks" "${EPHEMERAL_DIR}/.plugin_symlinks/flutter_plugin_registrant")

# Application
add_subdirectory("runner")

# Flutter library
add_subdirectory("flutter")

# Bundle libraries
if(CMAKE_BUILD_TYPE MATCHES "Debug")
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo
    "Built ${BINARY_NAME} ${CMAKE_BUILD_TYPE}")
endif()
