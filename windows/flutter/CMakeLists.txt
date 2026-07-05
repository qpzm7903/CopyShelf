cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../build/ephemeral/windows")

# Flutter library
add_library(flutter SHARED IMPORTED)
set_target_properties(flutter PROPERTIES
  IMPORTED_LOCATION "${EPHEMERAL_DIR}/flutter_windows.dll"
  IMPORTED_IMPLIB "${EPHEMERAL_DIR}/flutter_windows.dll.lib"
)

# Generated plugin registrant
add_subdirectory("${EPHEMERAL_DIR}/.plugin_symlinks/flutter_plugin_registrant"
  "${EPHEMERAL_DIR}/.plugin_symlinks/flutter_plugin_registrant")
