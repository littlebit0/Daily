#if os(iOS)
import AlarmKit
import Foundation

@available(iOS 26.0, *)
struct DailyAlarmMetadata: AlarmMetadata {
  let title: String
  let memo: String?
}
#endif
