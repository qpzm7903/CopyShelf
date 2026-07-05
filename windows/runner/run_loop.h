#ifndef RUNNER_RUN_LOOP_H_
#define RUNNER_RUN_LOOP_H_

#include <flutter/flutter_engine.h>

#include <chrono>
#include <set>
#include <functional>

class RunLoop {
 public:
  RunLoop();
  ~RunLoop();

  void Run();

 private:
  void ProcessTasks();
};

#endif  // RUNNER_RUN_LOOP_H_
