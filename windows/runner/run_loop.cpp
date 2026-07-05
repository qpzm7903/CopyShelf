#include "run_loop.h"

#include <windows.h>

RunLoop::RunLoop() {}

RunLoop::~RunLoop() {}

void RunLoop::Run() {
  bool done = false;
  while (!done) {
    MSG msg;
    if (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
      if (msg.message == WM_QUIT) {
        done = true;
      } else {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
      }
    } else {
      // Flush any pending tasks
      ProcessTasks();
      // Sleep briefly to avoid busy looping
      Sleep(1);
    }
  }
}

void RunLoop::ProcessTasks() {
  // Flutter engine processes its own tasks
  // No additional tasks to process
}
