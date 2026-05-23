#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

constexpr UINT kTrayIconId = 1;
constexpr UINT kTrayIconMessage = WM_APP + 1;
constexpr UINT kTrayOpenCommand = 40001;
constexpr UINT kTrayExitCommand = 40002;

}  // namespace

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

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  AddTrayIcon();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  switch (message) {
    case WM_CLOSE:
      if (!exit_requested_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
    case WM_COMMAND:
      switch (LOWORD(wparam)) {
        case kTrayOpenCommand:
          RestoreFromTray();
          return 0;
        case kTrayExitCommand:
          ExitFromTray();
          return 0;
      }
      break;
    case kTrayIconMessage:
      switch (LOWORD(lparam)) {
        case WM_LBUTTONUP:
        case WM_LBUTTONDBLCLK:
        case NIN_SELECT:
        case NIN_KEYSELECT:
          RestoreFromTray();
          return 0;
        case WM_RBUTTONUP:
        case WM_CONTEXTMENU:
          ShowTrayMenu();
          return 0;
      }
      break;
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

void FlutterWindow::AddTrayIcon() {
  if (tray_icon_added_) {
    return;
  }

  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  notify_icon_data_ = {};
  notify_icon_data_.cbSize = sizeof(NOTIFYICONDATA);
  notify_icon_data_.hWnd = hwnd;
  notify_icon_data_.uID = kTrayIconId;
  notify_icon_data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  notify_icon_data_.uCallbackMessage = kTrayIconMessage;
  notify_icon_data_.hIcon =
      LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(notify_icon_data_.szTip, L"Daily");

  tray_icon_added_ = Shell_NotifyIcon(NIM_ADD, &notify_icon_data_) == TRUE;
  if (tray_icon_added_) {
    notify_icon_data_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIcon(NIM_SETVERSION, &notify_icon_data_);
  }
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_icon_added_) {
    return;
  }

  Shell_NotifyIcon(NIM_DELETE, &notify_icon_data_);
  tray_icon_added_ = false;
}

void FlutterWindow::RestoreFromTray() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  ShowWindow(hwnd, SW_SHOW);
  ShowWindow(hwnd, SW_RESTORE);
  SetForegroundWindow(hwnd);
}

void FlutterWindow::ShowTrayMenu() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  HMENU menu = CreatePopupMenu();
  if (!menu) {
    return;
  }

  AppendMenu(menu, MF_STRING, kTrayOpenCommand, L"Open Daily");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, kTrayExitCommand, L"Exit");

  POINT cursor_position;
  GetCursorPos(&cursor_position);
  SetForegroundWindow(hwnd);
  TrackPopupMenu(menu, TPM_LEFTALIGN | TPM_BOTTOMALIGN | TPM_RIGHTBUTTON,
                 cursor_position.x, cursor_position.y, 0, hwnd, nullptr);
  DestroyMenu(menu);
}

void FlutterWindow::ExitFromTray() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    PostQuitMessage(0);
    return;
  }

  exit_requested_ = true;
  RemoveTrayIcon();
  DestroyWindow(hwnd);
}
