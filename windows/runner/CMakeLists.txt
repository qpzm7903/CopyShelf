cmake_minimum_required(VERSION 3.14)

set(BINARY_NAME "copyshelf")

set(RUNNER_SOURCES
  main.cpp
  flutter_window.cpp
  win32_window.cpp
  utils.cpp
  run_loop.cpp
)

add_executable(${BINARY_NAME} WIN32 ${RUNNER_SOURCES}
  "Runner.rc"
  "runner.exe.manifest"
)

target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${EPHEMERAL_DIR}"
)

target_link_libraries(${BINARY_NAME} PRIVATE
  flutter
  flutter_wrapper_texture
)

# Resource
set_target_properties(${BINARY_NAME} PROPERTIES
  WIN32_EXECUTABLE TRUE
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/runner"
)

# Bundle
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION .)
