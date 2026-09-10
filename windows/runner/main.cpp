#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

namespace {

void FitAndCenterWindowInWorkArea(HWND window) {
  if (window == nullptr) {
    return;
  }

  RECT window_rect{};
  if (!::GetWindowRect(window, &window_rect)) {
    return;
  }

  HMONITOR monitor = ::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  if (!::GetMonitorInfo(monitor, &monitor_info)) {
    return;
  }

  const int window_width = window_rect.right - window_rect.left;
  const int window_height = window_rect.bottom - window_rect.top;
  const int work_width = monitor_info.rcWork.right - monitor_info.rcWork.left;
  const int work_height = monitor_info.rcWork.bottom - monitor_info.rcWork.top;

  // Flutter's template scales the requested logical size by monitor DPI. On
  // common 125%-150% Windows scaling, 1280x720 can therefore be larger than
  // the usable work area. Keep a small margin and fit before centering so the
  // title bar, actions, and bottom content are reachable on first launch.
  const int horizontal_margin = work_width >= 900 ? 48 : 16;
  const int vertical_margin = work_height >= 700 ? 36 : 12;
  const int max_width = std::max(1, work_width - horizontal_margin * 2);
  const int max_height = std::max(1, work_height - vertical_margin * 2);
  const int target_width = std::min(window_width, max_width);
  const int target_height = std::min(window_height, max_height);

  const int x = monitor_info.rcWork.left + (work_width - target_width) / 2;
  const int y = monitor_info.rcWork.top + (work_height - target_height) / 2;

  ::SetWindowPos(window, nullptr, x, y, target_width, target_height,
                 SWP_NOZORDER | SWP_NOACTIVATE);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"\u5B66\u60C5", origin, size)) {
    return EXIT_FAILURE;
  }
  FitAndCenterWindowInWorkArea(window.GetHandle());
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
