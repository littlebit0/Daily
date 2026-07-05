import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

private final class DailyNativeNotifications {
  static let channelName = "daily/native_notifications"

  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "cancelPending":
        cancelPending(call, result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func cancelPending(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let id = intValue(arguments["id"]) else {
      result(FlutterError(code: "bad_arguments", message: "Invalid notification id", details: nil))
      return
    }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [String(id)])
    result(nil)
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
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let registrar = registrar(forPlugin: "DailyNativeNotifications") {
      DailyNativeNotifications.register(with: registrar.messenger())
    }
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
