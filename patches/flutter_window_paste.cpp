#include "flutter_window.h"

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <Shellapi.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = {0, 0, 600, 500};
  ::AdjustWindowRectEx(&frame, WS_OVERLAPPEDWINDOW, FALSE, 0);

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->EnsureDisplay()) {
    return false;
  }

  // Set up the paste platform channel
  SetupPasteChannel();

  // Register Flutter plugins
  RegisterPlugins(flutter_controller_->engine());

  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND window, UINT const message,
                                       WPARAM const wparam,
                                       LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    auto result = flutter_controller_->HandleTopLevelWindowProc(
        window, message, wparam, lparam);
    if (result.has_value()) {
      return result.value();
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(window, message, wparam, lparam);
}

void FlutterWindow::SetupPasteChannel() {
  auto& engine = *flutter_controller_->engine();
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine, "copyshelf/paste",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "paste") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto text_it = args->find(flutter::EncodableValue("text"));
            if (text_it != args->end()) {
              const auto text = std::get_if<std::string>(&text_it->second);
              if (text) {
                // 1. Write to clipboard
                if (!OpenClipboard(nullptr)) {
                  result->Error("CLIPBOARD_ERROR", "无法打开剪贴板");
                  return;
                }
                EmptyClipboard();

                HGLOBAL hGlobal = GlobalAlloc(GMEM_MOVEABLE, text->size() + 1);
                if (!hGlobal) {
                  CloseClipboard();
                  result->Error("MEMORY_ERROR", "无法分配内存");
                  return;
                }

                memcpy(GlobalLock(hGlobal), text->c_str(), text->size() + 1);
                GlobalUnlock(hGlobal);

                SetClipboardData(CF_TEXT, hGlobal);
                CloseClipboard();

                // 2. Simulate Ctrl+V
                INPUT inputs[2] = {};
                inputs[0].type = INPUT_KEYBOARD;
                inputs[0].ki.wVk = VK_CONTROL;
                inputs[0].ki.dwFlags = 0;  // Key down

                inputs[1].type = INPUT_KEYBOARD;
                inputs[1].ki.wVk = 'V';
                inputs[1].ki.dwFlags = 0;  // Key down

                SendInput(2, inputs, sizeof(INPUT));

                // Key up
                inputs[0].ki.dwFlags = KEYEVENTF_KEYUP;
                inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;
                SendInput(2, inputs, sizeof(INPUT));

                result->Success(flutter::EncodableValue(true));
                return;
              }
            }
          }
          result->Error("INVALID_ARGS", "参数无效");
        } else {
          result->NotImplemented();
        }
      });
}
