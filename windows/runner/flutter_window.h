#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shellapi.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void AddTrayIcon();
  void RemoveTrayIcon();
  void RestoreFromTray();
  void ShowTrayMenu();
  void ShowMiniCalendar();
  void ExitFromTray();
  std::wstring BuildMiniCalendarText();
  int FirstWeekday(int year, int month);
  int DaysInMonth(int year, int month);
  bool IsLeapYear(int year);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  NOTIFYICONDATA notify_icon_data_ = {};
  bool tray_icon_added_ = false;
  bool exit_requested_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
