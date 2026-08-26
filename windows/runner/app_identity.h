#ifndef RUNNER_APP_IDENTITY_H_
#define RUNNER_APP_IDENTITY_H_

namespace daily::app_identity {

#ifdef DAILY_TEST_EDITION
inline constexpr wchar_t kDisplayName[] = L"DailyCalendar Test";
inline constexpr wchar_t kOpenTrayLabel[] = L"Open DailyCalendar Test";
inline constexpr wchar_t kWidgetDataDirectoryName[] = L"DailyCalendar Test";
#else
inline constexpr wchar_t kDisplayName[] = L"DailyCalendar";
inline constexpr wchar_t kOpenTrayLabel[] = L"Open DailyCalendar";
inline constexpr wchar_t kWidgetDataDirectoryName[] = L"DailyCalendar";
#endif

}  // namespace daily::app_identity

#endif  // RUNNER_APP_IDENTITY_H_
