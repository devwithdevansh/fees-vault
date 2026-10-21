import Flutter
import UIKit
import LocalAuthentication

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var privacyOverlayView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let securityChannel = FlutterMethodChannel(
      name: "com.feesvault.security",
      binaryMessenger: controller.binaryMessenger
    )

    securityChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate unavailable", details: nil))
        return
      }

      if call.method == "applyFileProtectionAndBackupExclusion" {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Path argument required", details: nil))
          return
        }
        self.applySecurityAttributes(path: path, result: result)
      } else if call.method == "verifyFileProtection" {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Path argument required", details: nil))
          return
        }
        self.verifySecurityAttributes(path: path, result: result)
      } else if call.method == "openSecuritySettings" {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
          if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl, options: [:], completionHandler: { success in
              result(success)
            })
            return
          }
        }
        result(FlutterError(code: "SETTINGS_ERROR", message: "Cannot open iOS settings", details: nil))
      } else if call.method == "isDeviceLockEnrolled" {
        var authError: NSError?
        let context = LAContext()
        let isEnrolled = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError)
        result(isEnrolled)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    // Listen for screenshots and immediately trigger locking phase and privacy overlay
    NotificationCenter.default.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      securityChannel.invokeMethod("onScreenshotDetected", arguments: nil)
      self?.showPrivacyOverlay()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    showPrivacyOverlay()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    hidePrivacyOverlay()
  }

  private func showPrivacyOverlay() {
    guard let window = self.window, privacyOverlayView == nil else { return }
    let overlay = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    overlay.frame = window.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.tag = 998877
    window.addSubview(overlay)
    self.privacyOverlayView = overlay
  }

  private func hidePrivacyOverlay() {
    self.privacyOverlayView?.removeFromSuperview()
    self.privacyOverlayView = nil
    if let window = self.window, let view = window.viewWithTag(998877) {
      view.removeFromSuperview()
    }
  }

  private func applySecurityAttributes(path: String, result: @escaping FlutterResult) {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: path) else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Target path does not exist: \(path)", details: nil))
      return
    }

    do {
      var urlsToProcess: [URL] = [URL(fileURLWithPath: path)]
      var isDir: ObjCBool = false
      if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
        if let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil) {
          for case let fileURL as URL in enumerator {
            urlsToProcess.append(fileURL)
          }
        }
      }

      var processedCount = 0
      for var targetUrl in urlsToProcess {
        let filePath = targetUrl.path
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: filePath)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try targetUrl.setResourceValues(resourceValues)
        processedCount += 1
      }

      result([
        "success": true,
        "path": path,
        "itemsProcessed": processedCount,
        "protection": "FileProtectionType.complete",
        "isExcludedFromBackup": true
      ])
    } catch {
      result(FlutterError(code: "SECURITY_ATTR_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func verifySecurityAttributes(path: String, result: @escaping FlutterResult) {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: path) else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Target path does not exist: \(path)", details: nil))
      return
    }

    do {
      let attributes = try fileManager.attributesOfItem(atPath: path)
      let protectionKey = attributes[.protectionKey] as? FileProtectionType
      let isCompleteProtection = (protectionKey == .complete)

      let targetUrl = URL(fileURLWithPath: path)
      let resourceValues = try targetUrl.resourceValues(forKeys: [.isExcludedFromBackupKey])
      let isExcluded = resourceValues.isExcludedFromBackup ?? false

      var childDetails: [[String: Any]] = []
      var isDir: ObjCBool = false
      if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
        if let children = try? fileManager.contentsOfDirectory(atPath: path) {
          for child in children {
            let childPath = (path as NSString).appendingPathComponent(child)
            let childAttrs = try? fileManager.attributesOfItem(atPath: childPath)
            let childProt = childAttrs?[.protectionKey] as? FileProtectionType
            let childUrl = URL(fileURLWithPath: childPath)
            let childRes = try? childUrl.resourceValues(forKeys: [.isExcludedFromBackupKey])
            childDetails.append([
              "name": child,
              "protection": String(describing: childProt ?? .none),
              "isCompleteProtection": (childProt == .complete),
              "isExcludedFromBackup": childRes?.isExcludedFromBackup ?? false
            ])
          }
        }
      }

      let allVerified = isCompleteProtection && isExcluded && childDetails.allSatisfy {
        ($0["isCompleteProtection"] as? Bool ?? false) && ($0["isExcludedFromBackup"] as? Bool ?? false)
      }

      result([
        "verified": allVerified,
        "path": path,
        "protectionKey": String(describing: protectionKey ?? .none),
        "isCompleteProtection": isCompleteProtection,
        "isExcludedFromBackup": isExcluded,
        "sidecars": childDetails
      ])
    } catch {
      result(FlutterError(code: "VERIFICATION_ERROR", message: error.localizedDescription, details: nil))
    }
  }
}

