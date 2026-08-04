#include "flutter_window.h"

#include <ctime>
#include <commctrl.h>
#include <iomanip>
#include <optional>
#include <sstream>
#include <variant>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>
#include "resource.h"

namespace {

constexpr UINT kTrayIconId = 1;
constexpr UINT kTrayIconMessage = WM_APP + 1;
constexpr UINT kTrayOpenCommand = 40001;
constexpr UINT kTrayExitCommand = 40002;
constexpr UINT kTrayMiniCalendarCommand = 40003;

using TaskDialogIndirectFn = HRESULT(WINAPI*)(
    const TASKDIALOGCONFIG*, int*, int*, BOOL*);

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
  RegisterMapLauncherChannel();
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

void FlutterWindow::RegisterMapLauncherChannel() {
  map_launcher_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "daily/map_launcher",
          &flutter::StandardMethodCodec::GetInstance());
  map_launcher_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "openLocation") {
          result->NotImplemented();
          return;
        }
        OpenMapChooser(call, std::move(result));
      });
}

void FlutterWindow::OpenMapChooser(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    result->Error("bad_arguments", "A location is required.");
    return;
  }
  const auto iterator = arguments->find(flutter::EncodableValue("location"));
  if (iterator == arguments->end() ||
      !std::holds_alternative<std::string>(iterator->second)) {
    result->Error("bad_arguments", "A location is required.");
    return;
  }
  const auto& location = std::get<std::string>(iterator->second);
  if (location.empty()) {
    result->Error("bad_arguments", "A location is required.");
    return;
  }

  TASKDIALOG_BUTTON buttons[] = {
      {1001, L"카카오맵"},
      {1002, L"네이버지도"},
      {IDCANCEL, L"취소"},
  };
  TASKDIALOGCONFIG config = {};
  config.cbSize = sizeof(config);
  config.hwndParent = GetHandle();
  config.dwFlags = TDF_ALLOW_DIALOG_CANCELLATION;
  config.pszWindowTitle = L"Daily";
  config.pszMainInstruction = L"지도에서 열기";
  config.pszContent = L"선택한 지도 서비스의 웹사이트가 기본 브라우저에서 열립니다.";
  config.cButtons = ARRAYSIZE(buttons);
  config.pButtons = buttons;
  config.nDefaultButton = IDCANCEL;

  int selected = IDCANCEL;
  // TaskDialogIndirect is only exported by Common Controls v6. Resolve it at
  // runtime so an installation with the legacy control library can still open
  // the application and use the map chooser fallback.
  HMODULE common_controls = LoadLibraryW(L"comctl32.dll");
  const auto task_dialog = common_controls == nullptr
      ? nullptr
      : reinterpret_cast<TaskDialogIndirectFn>(
            GetProcAddress(common_controls, "TaskDialogIndirect"));
  if (task_dialog != nullptr) {
    task_dialog(&config, &selected, nullptr, nullptr);
  } else {
    const int fallback = MessageBoxW(
        GetHandle(),
        L"Yes: Kakao Map\nNo: Naver Map\nCancel: Close",
        L"Daily", MB_YESNOCANCEL | MB_ICONQUESTION);
    selected = fallback == IDYES ? 1001 : fallback == IDNO ? 1002 : IDCANCEL;
  }
  if (common_controls != nullptr) {
    FreeLibrary(common_controls);
  }
  switch (selected) {
    case 1001:
      result->Success(flutter::EncodableValue("kakao"));
      break;
    case 1002:
      result->Success(flutter::EncodableValue("naver"));
      break;
    default:
      result->Success(flutter::EncodableValue("handled"));
      break;
  }
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
        case kTrayMiniCalendarCommand:
          ShowMiniCalendar();
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
  AppendMenu(menu, MF_STRING, kTrayMiniCalendarCommand, L"Mini Calendar");
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

void FlutterWindow::ShowMiniCalendar() {
  HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  MessageBox(hwnd, BuildMiniCalendarText().c_str(), L"Daily Mini Calendar",
             MB_OK | MB_ICONINFORMATION);
}

std::wstring FlutterWindow::BuildMiniCalendarText() {
  std::time_t now_time = std::time(nullptr);
  std::tm now = {};
  localtime_s(&now, &now_time);

  const int year = now.tm_year + 1900;
  const int month = now.tm_mon + 1;
  const int today = now.tm_mday;
  const int first_weekday = FirstWeekday(year, month);
  const int days_in_month = DaysInMonth(year, month);

  std::wstringstream stream;
  stream << year << L"." << std::setw(2) << std::setfill(L'0') << month
         << L"\n\n";
  stream << L"Sun Mon Tue Wed Thu Fri Sat\n";

  for (int i = 0; i < first_weekday; ++i) {
    stream << L"    ";
  }

  for (int day = 1; day <= days_in_month; ++day) {
    if (day == today) {
      stream << L"[" << std::setw(2) << std::setfill(L' ') << day << L"]";
    } else {
      stream << L" " << std::setw(2) << std::setfill(L' ') << day << L" ";
    }
    if ((first_weekday + day) % 7 == 0) {
      stream << L"\n";
    }
  }

  stream << L"\n\nOpen Daily to view and add schedules.";
  return stream.str();
}

int FlutterWindow::FirstWeekday(int year, int month) {
  std::tm first = {};
  first.tm_year = year - 1900;
  first.tm_mon = month - 1;
  first.tm_mday = 1;
  std::mktime(&first);
  return first.tm_wday;
}

int FlutterWindow::DaysInMonth(int year, int month) {
  static const int days[] = {31, 28, 31, 30, 31, 30,
                             31, 31, 30, 31, 30, 31};
  if (month == 2 && IsLeapYear(year)) {
    return 29;
  }
  return days[month - 1];
}

bool FlutterWindow::IsLeapYear(int year) {
  return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}
