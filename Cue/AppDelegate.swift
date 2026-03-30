//
//  AppDelegate.swift
//  Cue
//
//  Minimal UIApplicationDelegate so Firebase/GoogleUtilities can swizzle safely.
//  Swizzles deprecated openURL(_:) to use open(_:options:completionHandler:) so
//  the Spotify SDK's authorizeAndPlayURI can open the Spotify app on iOS 18+.
//

import UIKit
import ObjectiveC
import FirebaseCore

private let openURLSwizzled: Void = {
    guard let original = class_getInstanceMethod(UIApplication.self, NSSelectorFromString("openURL:")),
          let replacement = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.cue_openURL(_:)))
    else { return }
    method_exchangeImplementations(original, replacement)
}()

extension UIApplication {
    @objc fileprivate func cue_openURL(_ url: URL) -> Bool {
        // Use the non-deprecated API so iOS 18+ doesn't force false. Don't block the caller.
        open(url, options: [:]) { _ in }
        return true
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = openURLSwizzled
        // Configure after UIApplication’s delegate is set so Firebase/GoogleUtilities swizzling sees a real UIApplicationDelegate.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }

    /// Fallback URL handler for Spotify App Remote callback.
    /// SwiftUI's onOpenURL can miss the redirect when returning from the Spotify app on device.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        SpotifyManager.shared.handleURL(url)
        return true
    }
}
