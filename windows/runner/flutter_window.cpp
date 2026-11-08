#include "flutter_window.h"

#include <cstring>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  launch_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "visor-config/launch",
      &flutter::StandardMethodCodec::GetInstance());
  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    Show();
    first_frame_rendered_ = true;
    for (const auto& request : pending_launches_) DeliverLaunch(request);
    pending_launches_.clear();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  launch_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::DeliverLaunch(const flutter::EncodableValue& request) {
  launch_channel_->InvokeMethod(
      "open", std::make_unique<flutter::EncodableValue>(request));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_COPYDATA) {
    const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
    if (data == nullptr || data->dwData != kLaunchMessage ||
        data->cbData == 0 || data->lpData == nullptr) return FALSE;

    const char* cursor = static_cast<const char*>(data->lpData);
    const char* end = cursor + data->cbData;
    flutter::EncodableList arguments;
    const char* separator = static_cast<const char*>(std::memchr(cursor, 0, end - cursor));
    if (separator == nullptr) return FALSE;
    std::string cwd(cursor, separator);
    cursor = separator + 1;
    while (cursor < end) {
      separator = static_cast<const char*>(std::memchr(cursor, 0, end - cursor));
      if (separator == nullptr) return FALSE;
      arguments.emplace_back(std::string(cursor, separator));
      cursor = separator + 1;
    }

    if (!arguments.empty()) {
      flutter::EncodableValue request(flutter::EncodableMap{
          {flutter::EncodableValue("arguments"), flutter::EncodableValue(arguments)},
          {flutter::EncodableValue("cwd"), flutter::EncodableValue(cwd)},
      });
      if (first_frame_rendered_) {
        DeliverLaunch(request);
      } else {
        pending_launches_.push_back(std::move(request));
      }
    }
    if (first_frame_rendered_) {
      if (::IsIconic(hwnd)) ::ShowWindow(hwnd, SW_RESTORE);
      ::SetForegroundWindow(hwnd);
    }
    return TRUE;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
