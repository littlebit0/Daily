import Flutter
import AuthenticationServices
import UIKit
import UserNotifications
import flutter_local_notifications

private final class DailyGoogleOAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
  static let channelName = "daily/google_oauth"

  private var session: ASWebAuthenticationSession?
  private var flutterResult: FlutterResult?
  private var fallbackPresentationWindow: UIWindow?

  func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "authorize":
        self?.authorize(call, result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func authorize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard flutterResult == nil else {
      result(FlutterError(code: "busy", message: "Google 인증이 이미 진행 중입니다.", details: nil))
      return
    }
    guard let arguments = call.arguments as? [String: Any],
          let urlValue = arguments["authorizationUrl"] as? String,
          let url = URL(string: urlValue),
          let callbackUrlScheme = arguments["callbackUrlScheme"] as? String,
          !callbackUrlScheme.isEmpty else {
      result(FlutterError(code: "bad_arguments", message: "Invalid Google OAuth arguments", details: nil))
      return
    }

    flutterResult = result
    startAuthorizationSession(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      allowPresentationRetry: true
    )
  }

  private func startAuthorizationSession(
    url: URL,
    callbackUrlScheme: String,
    allowPresentationRetry: Bool
  ) {
    let authSession = ASWebAuthenticationSession(
      url: url,
      callbackURLScheme: callbackUrlScheme
    ) { [weak self] callbackURL, error in
      guard let self = self else { return }
      if self.shouldRetryPresentation(error, allowPresentationRetry) {
        self.session = nil
        self.fallbackPresentationWindow?.isHidden = true
        self.fallbackPresentationWindow = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
          guard let self = self, self.flutterResult != nil else { return }
          self.startAuthorizationSession(
            url: url,
            callbackUrlScheme: callbackUrlScheme,
            allowPresentationRetry: false
          )
        }
        return
      }

      let pendingResult = self.flutterResult
      self.flutterResult = nil
      self.session = nil
      self.fallbackPresentationWindow?.isHidden = true
      self.fallbackPresentationWindow = nil

      if let callbackURL = callbackURL {
        pendingResult?(callbackURL.absoluteString)
        return
      }
      if let authError = error as? ASWebAuthenticationSessionError,
         authError.code == .canceledLogin {
        pendingResult?(FlutterError(code: "canceled", message: "Google Drive 연결이 취소되었습니다.", details: nil))
        return
      }
      pendingResult?(FlutterError(
        code: "failed",
        message: error?.localizedDescription ?? "Google 인증 창을 완료하지 못했습니다.",
        details: nil
      ))
    }
    authSession.presentationContextProvider = self
    authSession.prefersEphemeralWebBrowserSession = false
    session = authSession
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.session === authSession else { return }
      if authSession.start() {
        return
      }
      flutterResult = nil
      session = nil
      fallbackPresentationWindow?.isHidden = true
      fallbackPresentationWindow = nil
      let pendingResult = self.flutterResult
      self.flutterResult = nil
      pendingResult?(
        FlutterError(code: "failed", message: "Google 인증 창을 열 수 없습니다.", details: nil)
      )
    }
  }

  private func shouldRetryPresentation(_ error: Error?, _ allowPresentationRetry: Bool) -> Bool {
    guard allowPresentationRetry,
          let authError = error as? ASWebAuthenticationSessionError else {
      return false
    }
    return authError.code.rawValue == 3
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    if let window = Self.activePresentationWindow() {
      return window
    }

    let foregroundScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { scene in
        scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive
      }

    guard let windowScene = foregroundScenes.first else {
      return ASPresentationAnchor()
    }

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = UIViewController()
    window.windowLevel = .normal
    window.backgroundColor = .clear
    window.isHidden = false
    fallbackPresentationWindow = window
    return window
  }

  private static func activePresentationWindow() -> UIWindow? {
    let foregroundWindows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { scene in
        scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive
      }
      .flatMap(\.windows)

    return foregroundWindows.first { $0.isKeyWindow }
      ?? foregroundWindows.first {
        !$0.isHidden && $0.alpha > 0 && $0.windowLevel == .normal
      }
      ?? foregroundWindows.first
  }
}

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
  private let googleOAuthSession = DailyGoogleOAuthSession()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let registrar = registrar(forPlugin: "DailyNativeNotifications") {
      DailyNativeNotifications.register(with: registrar.messenger())
    }
    if let registrar = registrar(forPlugin: "DailyGoogleOAuthSession") {
      googleOAuthSession.register(with: registrar.messenger())
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
