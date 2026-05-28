import Cocoa
import FlutterMacOS
import UserNotifications

private final class DailyNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
  static let shared = DailyNotificationCenterDelegate()

  static func install() {
    UNUserNotificationCenter.current().delegate = shared
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(macOS 11.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}

private final class DailyNativeNotifications {
  static let channelName = "daily/native_notifications"

  static func register(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "initialize":
        initialize(result)
      case "checkPermissions":
        checkPermissions(result)
      case "show":
        show(call, result)
      case "schedule":
        schedule(call, result)
      case "cancel":
        cancel(call, result)
      case "pendingCount":
        pendingCount(result)
      case "deliveredCount":
        deliveredCount(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func initialize(_ result: @escaping FlutterResult) {
    DailyNotificationCenterDelegate.install()
    var options: UNAuthorizationOptions = [.alert, .sound, .badge]
    if #available(macOS 12.0, *) {
      options.insert(.timeSensitive)
    }
    UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
      finish(result, error: error, value: granted)
    }
  }

  private static func checkPermissions(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let value: [String: Any] = [
        "isEnabled": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
        "isSoundEnabled": settings.soundSetting == .enabled,
        "isAlertEnabled": settings.alertSetting == .enabled,
        "isBadgeEnabled": settings.badgeSetting == .enabled,
        "notificationCenterEnabled": settings.notificationCenterSetting == .enabled,
        "alertStyle": settings.alertStyle.rawValue,
        "scheduledDeliveryEnabled": scheduledDeliveryEnabled(settings),
        "timeSensitiveEnabled": timeSensitiveEnabled(settings),
      ]
      finish(result, value: value)
    }
  }

  private static func scheduledDeliveryEnabled(_ settings: UNNotificationSettings) -> Bool {
    if #available(macOS 12.0, *) {
      return settings.scheduledDeliverySetting == .enabled
    }
    return true
  }

  private static func timeSensitiveEnabled(_ settings: UNNotificationSettings) -> Bool {
    if #available(macOS 12.0, *) {
      return settings.timeSensitiveSetting == .enabled
    }
    return true
  }

  private static func show(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "bad_arguments", message: "Invalid notification arguments", details: nil))
      return
    }
    DailyNotificationCenterDelegate.install()
    addNotification(from: arguments, trigger: nil, result)
  }

  private static func schedule(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let scheduledAtMillis = int64Value(arguments["scheduledAtMillis"]) else {
      result(FlutterError(code: "bad_arguments", message: "Invalid notification schedule arguments", details: nil))
      return
    }

    let scheduledDate = Date(timeIntervalSince1970: TimeInterval(scheduledAtMillis) / 1000.0)
    let repeatsDaily = arguments["repeatsDaily"] as? Bool == true
    let trigger: UNNotificationTrigger
    var calendar = Calendar.current
    calendar.timeZone = TimeZone.current
    if repeatsDaily {
      let components = calendar.dateComponents([.hour, .minute, .second, .timeZone], from: scheduledDate)
      trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    } else {
      trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: max(scheduledDate.timeIntervalSinceNow, 1.0),
        repeats: false
      )
    }
    DailyNotificationCenterDelegate.install()
    addNotification(from: arguments, trigger: trigger, result)
  }

  private static func cancel(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let id = intValue(arguments["id"]) else {
      result(FlutterError(code: "bad_arguments", message: "Invalid notification id", details: nil))
      return
    }
    let identifiers = [String(id)]
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
    center.removeDeliveredNotifications(withIdentifiers: identifiers)
    result(nil)
  }

  private static func pendingCount(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      finish(result, value: requests.count)
    }
  }

  private static func deliveredCount(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
      finish(result, value: notifications.count)
    }
  }

  private static func notificationRequest(
    from arguments: [String: Any],
    trigger: UNNotificationTrigger?,
    settings: UNNotificationSettings
  ) -> UNNotificationRequest? {
    guard let id = intValue(arguments["id"]) else {
      return nil
    }
    let content = UNMutableNotificationContent()
    content.title = arguments["title"] as? String ?? "Daily"
    content.body = arguments["body"] as? String ?? ""
    content.sound = .default
    content.userInfo = ["payload": arguments["payload"] as? String ?? ""]
    if #available(macOS 12.0, *) {
      content.interruptionLevel = settings.timeSensitiveSetting == .enabled
        ? .timeSensitive
        : .active
    }
    return UNNotificationRequest(
      identifier: String(id),
      content: content,
      trigger: trigger
    )
  }

  private static func addNotification(
    from arguments: [String: Any],
    trigger: UNNotificationTrigger?,
    _ result: @escaping FlutterResult
  ) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      guard let request = notificationRequest(from: arguments, trigger: trigger, settings: settings) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "bad_arguments",
            message: "Invalid notification request arguments",
            details: nil
          ))
        }
        return
      }
      add(request, result)
    }
  }

  private static func add(_ request: UNNotificationRequest, _ result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
    center.add(request) { error in
      finish(result, error: error, value: nil)
    }
  }

  private static func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }
    if let value = value as? NSNumber {
      return value.intValue
    }
    return nil
  }

  private static func int64Value(_ value: Any?) -> Int64? {
    if let value = value as? Int64 {
      return value
    }
    if let value = value as? Int {
      return Int64(value)
    }
    if let value = value as? NSNumber {
      return value.int64Value
    }
    return nil
  }

  private static func finish(
    _ result: @escaping FlutterResult,
    error: Error? = nil,
    value: Any?
  ) {
    DispatchQueue.main.async {
      if let error = error {
        result(FlutterError(
          code: "notification_error",
          message: error.localizedDescription,
          details: "\(error)"
        ))
        return
      }
      result(value)
    }
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    DailyNativeNotifications.register(with: flutterViewController)
    DailyNotificationCenterDelegate.install()

    super.awakeFromNib()
  }
}
