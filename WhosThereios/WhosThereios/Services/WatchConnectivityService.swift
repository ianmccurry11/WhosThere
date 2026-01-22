//
//  WatchConnectivityService.swift
//  WhosThereios
//
//  Created by Claude on 1/18/26.
//

import Foundation
import WatchConnectivity
import FirebaseAuth

class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    private var session: WCSession?
    private var firestoreService: FirestoreService { FirestoreService.shared }
    private var presenceService: PresenceService { PresenceService.shared }

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Send Data to Watch

    func sendGroupsToWatch() {
        guard let session = session, session.isPaired, session.isWatchAppInstalled else {
            return
        }

        let userId = Auth.auth().currentUser?.uid ?? ""

        let watchGroups = firestoreService.joinedGroups.map { group -> [String: Any] in
            let groupId = group.id ?? ""
            let summary = presenceService.getPresenceSummary(for: groupId)
            let presenceCount = summary?.presentCount ?? 0
            let isUserPresent = presenceService.isUserPresent(groupId: groupId, userId: userId)

            return [
                "id": groupId,
                "name": group.name,
                "emoji": group.displayEmoji,
                "centerLatitude": group.centerLatitude,
                "centerLongitude": group.centerLongitude,
                "presentCount": presenceCount,
                "isUserPresent": isUserPresent
            ]
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: watchGroups)
            try session.updateApplicationContext(["groups": data])
        } catch {
            print("Error sending groups to watch: \(error)")
        }
    }

    func sendPresenceUpdate(groupId: String) {
        guard let session = session, session.isReachable else { return }

        let userId = Auth.auth().currentUser?.uid ?? ""
        let summary = presenceService.getPresenceSummary(for: groupId)
        let presenceCount = summary?.presentCount ?? 0
        let isUserPresent = presenceService.isUserPresent(groupId: groupId, userId: userId)

        let message: [String: Any] = [
            "groupId": groupId,
            "presentCount": presenceCount,
            "isUserPresent": isUserPresent
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending presence update: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            Task { @MainActor in
                self.sendGroupsToWatch()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            await handleWatchMessage(message)
        }
    }

    @MainActor
    private func handleWatchMessage(_ message: [String: Any]) async {
        guard let action = message["action"] as? String else { return }

        switch action {
        case "requestGroups":
            sendGroupsToWatch()

        case "toggleCheckIn":
            if let groupId = message["groupId"] as? String,
               let checkIn = message["checkIn"] as? Bool {
                await handleCheckInToggle(groupId: groupId, checkIn: checkIn)
            }

        default:
            break
        }
    }

    @MainActor
    private func handleCheckInToggle(groupId: String, checkIn: Bool) async {
        if checkIn {
            await presenceService.manualCheckIn(groupId: groupId)
        } else {
            await presenceService.manualCheckOut(groupId: groupId)
        }

        // Send updated presence back to watch
        sendPresenceUpdate(groupId: groupId)
    }
}
