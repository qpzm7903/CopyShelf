#include "utils.h"

#include <windows.h>

std::vector<std::string> GetCommandLineArguments() {
  LPWSTR* command_line_args;
  int arg_count;

  command_line_args = CommandLineToArgvW(GetCommandLineW(), &arg_count);
  if (command_line_args == nullptr) {
    return {};
  }

  std::vector<std::string> args;
  for (int i = 0; i < arg_count; i++) {
    int length = WideCharToMultiByte(CP_UTF8, 0, command_line_args[i], -1,
                                      nullptr, 0, nullptr, nullptr);
    std::string arg(length - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, command_line_args[i], -1, arg.data(),
                        length, nullptr, nullptr);
    args.push_back(std::move(arg));
  }

  LocalFree(command_line_args);
  return args;
}
