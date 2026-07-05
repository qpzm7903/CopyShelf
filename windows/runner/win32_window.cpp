#include "win32_window.h"

#include <flutter_windows.h>

#include <stdexcept>

Win32Window::Win32Window() {}

Win32Window::~Win32Window() {
  Destroy();
}

bool Win32Window::Create(const std::wstring& title, const Point& origin,
                          const Size& size) {
  Destroy();

  WNDCLASS window_class = {};
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = L"FlutterWindowClass";
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.cbClsExtra = 0;
  window_class.cbWndExtra = 0;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.hIcon = nullptr;
  window_class.hbrBackground = nullptr;
  window_class.lpszMenuName = nullptr;
  window_class.lpfnWndProc = &WndProc;

  if (!RegisterClass(&window_class)) {
    return false;
  }

  window_handle_ = CreateWindowEx(
      WS_EX_APPWINDOW | WS_EX_WINDOWEDGE,
      L"FlutterWindowClass",
      title.c_str(),
      WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN,
      origin.x, origin.y,
      size.width, size.height,
      nullptr, nullptr,
      GetModuleHandle(nullptr), this);

  if (!window_handle_) {
    return false;
  }

  return OnCreate();
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }

  UnregisterClass(L"FlutterWindowClass", GetModuleHandle(nullptr));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

HWND Win32Window::GetHandle() const {
  return window_handle_;
}

bool Win32Window::OnCreate() {
  return true;
}

void Win32Window::OnDestroy() {}

LRESULT Win32Window::MessageHandler(HWND window, UINT const message,
                                     WPARAM const wparam,
                                     LPARAM const lparam) noexcept {
  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT CALLBACK Win32Window::WndProc(HWND window, UINT message,
                                       WPARAM wparam, LPARAM lparam) {
  Win32Window* self = nullptr;
  if (message == WM_NCCREATE) {
    auto cs = reinterpret_cast<CREATESTRUCT*>(lparam);
    self = reinterpret_cast<Win32Window*>(cs->lpCreateParams);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(self));
  } else {
    self = reinterpret_cast<Win32Window*>(
        GetWindowLongPtr(window, GWLP_USERDATA));
  }

  LRESULT result = 0;
  if (self) {
    result = self->MessageHandler(window, message, wparam, lparam);
  } else {
    result = DefWindowProc(window, message, wparam, lparam);
  }
  return result;
}
