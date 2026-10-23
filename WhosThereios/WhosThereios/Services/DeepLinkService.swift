//
//  DeepLinkService.swift
//  WhosThereios
//
//  Created by Claude on 2/6/26.
//

import Foundation
import Combine

@MainActor
class DeepLinkService: ObservableObject {
    static let shared = DeepLinkService()

    static let hostingDomain = "whostherefb.web.app"

    @Published var pendingGroupId: String?
    @Published var pendingInviteCode: String?

    func handleURL(_ url: URL) {
        AppLogger.debug("DeepLinkService handling URL: \(url)")

        // Handle custom scheme: whosthere://join/{inviteCode} or whosthere://group/{groupId}
        if url.scheme == "whosthere" {
            handleCustomScheme(url)
            return
        }

        // Handle universal link: https://whostherefb.web.app/join/{inviteCode}
        // or https://whostherefb.web.app/group/{groupId}
        if url.host == Self.hostingDomain {
            handleUniversalLink(url)
            return
        }
    }

    private func handleCustomScheme(_ url: URL) {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard let action = url.host ?? pathComponents.first else { return }

        switch action {
        case "join":
            if let code = pathComponents.first(where: { $0 != "join" }) ?? url.pathComponents.last {
                if code != "/" && code != "join" {
                    pendingInviteCode = code.uppercased()
                }
            }
        case "group":
            if let groupId = pathComponents.first(where: { $0 != "group" }) ?? url.pathComponents.last {
                if groupId != "/" && groupId != "group" {
                    pendingGroupId = groupId
                }
            }
        default:
            break
        }
    }

    private func handleUniversalLink(_ url: URL) {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard pathComponents.count >= 2 else { return }

        switch pathComponents[0] {
        case "join":
            pendingInviteCode = pathComponents[1].uppercased()
        case "group":
            pendingGroupId = pathComponents[1]
        default:
            break
        }
    }

    func generateShareLink(inviteCode: String) -> URL? {
        URL(string: "https://\(Self.hostingDomain)/join/\(inviteCode)")
    }

    func generateGroupLink(groupId: String) -> URL? {
        URL(string: "https://\(Self.hostingDomain)/group/\(groupId)")
    }

    func clearPending() {
        pendingGroupId = nil
        pendingInviteCode = nil
    }
}
