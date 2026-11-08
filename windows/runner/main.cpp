#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <filesystem>

#include "flutter_window.h"
#include "utils.h"

namespace {

bool RequiresConsole(const std::vector<std::string>& arguments) {
  for (size_t i = 0; i < arguments.size(); ++i) {
    const auto& arg = arguments[i];
    if (arg == "--") break;
    if ((arg == "--file" || arg == "--json") && i + 1 < arguments.size()) {
      ++i;
      continue;
    }
    if (arg.rfind("--", 0) == 0) return true;
  }
  return false;
}

bool ForwardLaunch(HWND window, const std::vector<std::string>& arguments) {
  std::error_code error;
  const auto cwd = std::filesystem::current_path(error);
  if (error) return false;
  std::string payload = Utf8FromUtf16(cwd.c_str());
  payload.push_back('\0');
  for (const auto& argument : arguments) {
    payload.append(argument);
    payload.push_back('\0');
  }
  COPYDATASTRUCT data{FlutterWindow::kLaunchMessage,
                      static_cast<DWORD>(payload.size()), payload.data()};
  DWORD process_id = 0;
  ::GetWindowThreadProcessId(window, &process_id);
  ::AllowSetForegroundWindow(process_id);
  DWORD_PTR accepted = 0;
  return ::SendMessageTimeout(window, WM_COPYDATA, 0,
                              reinterpret_cast<LPARAM>(&data),
                              SMTO_ABORTIFHUNG | SMTO_BLOCK, 5000, &accepted) &&
         accepted;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  auto arguments = GetCommandLineArguments();
  const bool console_only = RequiresConsole(arguments);
  // Serialize window discovery and creation so simultaneous launches cannot
  // both start an instance.
  std::unique_ptr<void, decltype(&::CloseHandle)> startup_lock(
      console_only ? nullptr : ::CreateMutexW(nullptr, FALSE, L"Local\\VisorConfigStartup"),
      &::CloseHandle);
  if (!console_only) {
    if (!startup_lock) return EXIT_FAILURE;
    const DWORD wait = ::WaitForSingleObject(startup_lock.get(), 10000);
    if (wait != WAIT_OBJECT_0 && wait != WAIT_ABANDONED) return EXIT_FAILURE;
    HWND existing = ::FindWindowW(L"VISOR_CONFIG_WIN32_WINDOW", FlutterWindow::kWindowTitle);
    if (existing != nullptr) {
      ::ReleaseMutex(startup_lock.get());
      return ForwardLaunch(existing, arguments) ? EXIT_SUCCESS : EXIT_FAILURE;
    }
  }

  // Initialize COM for the engine and plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  const bool created = window.Create(
      console_only ? L"Visor Config CLI" : FlutterWindow::kWindowTitle, origin, size);
  if (startup_lock) ::ReleaseMutex(startup_lock.get());
  if (!created) return EXIT_FAILURE;
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
