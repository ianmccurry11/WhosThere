//
//  NotificationService.swift
//  WhosThereios
//
//  Created by Claude on 1/20/26.
//

import Foundation
import UserNotifications
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import Combine

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    private let db = Firestore.firestore()
    private var firestoreService: FirestoreService { FirestoreService.shared }

    @Published var isAuthorized = false
    @Published var fcmToken: String?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }

    // MARK: - Setup

    func configure() {
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Permission Handling

    func requestPermissions() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            isAuthorized = granted

            if granted {
                await registerForRemoteNotifications()
            }

            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized

        if isAuthorized {
            await registerForRemoteNotifications()
        }
    }

    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Token Management

    func updateFCMToken(_ token: String) async {
        self.fcmToken = token

        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(userId).setData([
                "fcmToken": token
            ], merge: true)
            print("FCM token updated in Firestore")
        } catch {
            print("Error updating FCM token: \(error)")
        }
    }

    func clearFCMToken() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(userId).updateData([
                "fcmToken": FieldValue.delete()
            ])
            fcmToken = nil
            print("FCM token cleared")
        } catch {
            print("Error clearing FCM token: \(error)")
        }
    }

    // MARK: - APNs Token (called from AppDelegate)

    func setAPNsToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - Notification Preferences

    func getNotificationPreferences(groupId: String) async -> NotificationPreferences? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }

        do {
            let doc = try await db.collection("users").document(userId)
                .collection("notificationPreferences").document(groupId).getDocument()

            if doc.exists {
                return try doc.data(as: NotificationPreferences.self)
            }
            return nil
        } catch {
            print("Error fetching notification preferences: \(error)")
            return nil
        }
    }

    func updateNotificationPreferences(groupId: String, preferences: NotificationPreferences) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try db.collection("users").document(userId)
                .collection("notificationPreferences").document(groupId)
                .setData(from: preferences, merge: true)
            print("Notification preferences updated for group: \(groupId)")
        } catch {
            print("Error updating notification preferences: \(error)")
        }
    }

    func deleteNotificationPreferences(groupId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(userId)
                .collection("notificationPreferences").document(groupId).delete()
        } catch {
            print("Error deleting notification preferences: \(error)")
        }
    }

    // MARK: - Local Notifications (for testing/fallback)

    func sendLocalNotification(title: String, body: String, groupId: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let groupId = groupId {
            content.userInfo = ["groupId": groupId]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending local notification: \(error)")
            }
        }
    }

    // MARK: - Friend Arrival Notification

    func notifyFriendArrival(friendName: String, groupName: String, groupEmoji: String, groupId: String) {
        sendLocalNotification(
            title: "\(groupEmoji) \(friendName) arrived!",
            body: "\(friendName) just checked in at \(groupName)",
            groupId: groupId
        )
    }

    // MARK: - Friend Request Notification

    func notifyFriendRequest(senderName: String) {
        sendLocalNotification(
            title: "New Friend Request",
            body: "\(senderName) wants to be your friend"
        )
    }

    // MARK: - Handle Received Notification

    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        // Handle notification tap
        if let groupId = userInfo["groupId"] as? String {
            // Navigate to group
            NotificationCenter.default.post(
                name: .openGroup,
                object: nil,
                userInfo: ["groupId": groupId]
            )
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        return [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            handleNotification(userInfo)
        }
    }
}

// MARK: - MessagingDelegate

extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM token received: \(token)")

        Task { @MainActor in
            await self.updateFCMToken(token)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openGroup = Notification.Name("openGroup")
    static let friendRequestReceived = Notification.Name("friendRequestReceived")
}
