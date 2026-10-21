//
//  WhosThereiosApp.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Initialize Watch Connectivity
        _ = WatchConnectivityService.shared

        // Configure notifications
        NotificationService.shared.configure()

        // Create the presence + location services now, not when the first view
        // appears: when iOS relaunches the app in the background for a geofence,
        // visit or significant move, there is no UI, and the event would be lost
        _ = PresenceService.shared

        return true
    }

    // Handle APNs token registration
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass the APNs token to Firebase Messaging
        NotificationService.shared.setAPNsToken(deviceToken)

        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        AppLogger.debug("APNs token received: \(tokenString)")
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppLogger.debug("Failed to register for remote notifications: \(error)")
    }

    // Handle notification when app is in background
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        // Silent "are you still there?" push from the presenceSweep /
        // onPresenceRecheckRequest Cloud Functions
        if userInfo["type"] as? String == "presenceRecheck" {
            await PresenceService.shared.confirmPresence(reason: "recheck")
            return .newData
        }

        // Handle the notification
        NotificationService.shared.handleNotification(userInfo)
        return .newData
    }
}

@main
struct WhosThereiosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    DeepLinkService.shared.handleURL(url)
                }
        }
    }
}
