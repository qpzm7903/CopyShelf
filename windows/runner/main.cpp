#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "run_loop.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run')
  if (::AttachConsole(ATTACH_PARENT_PROCESS) || ::IsDebuggerPresent()) {
    ::AllocConsole();
    ::freopen("CONOUT$", "w", stdout);
    ::freopen("CONOUT$", "w", stderr);
  }

  // Resources
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  RunLoop run_loop;

  flutter::DartProject project(L"data");

  // Command-line arguments
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(600, 500);
  if (!window.Create(L"copyshelf", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  run_loop.Run();

  ::CoUninitialize();
  ::FreeConsole();

  return EXIT_SUCCESS;
}
