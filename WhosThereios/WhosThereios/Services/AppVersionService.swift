//
//  AppVersionService.swift
//  WhosThereios
//

import Foundation
import Combine
import FirebaseFirestore

/// Blocks the app when it's older than the minimum version set in Firestore.
///
/// To force everyone below a version to update, set `minimumVersion` (a
/// string such as "1.2.5") on the `config/app` document in the Firebase
/// console. An optional `updateMessage` string replaces the default text.
/// Open apps pick up the change immediately; nothing needs to be released.
@MainActor
class AppVersionService: ObservableObject {
    static let shared = AppVersionService()

    @Published private(set) var isUpdateRequired = false
    @Published private(set) var updateMessage: String?

    /// Who's There on the App Store
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6758129477")

    private var listener: ListenerRegistration?

    /// The version the user is running, e.g. "1.2.5"
    var installedVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Watches the config document so raising the minimum takes effect live
    func startListening() {
        guard listener == nil else { return }
        listener = Firestore.firestore().collection("config").document("app")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    // Never lock people out because the check itself failed
                    guard let data = snapshot?.data() else {
                        if let error {
                            AppLogger.debug("[AppVersionService] Config read failed: \(error)")
                        }
                        self.isUpdateRequired = false
                        return
                    }
                    self.apply(config: data)
                }
            }
    }

    private func apply(config: [String: Any]) {
        guard let minimumVersion = config["minimumVersion"] as? String,
              !minimumVersion.isEmpty else {
            isUpdateRequired = false
            return
        }
        updateMessage = config["updateMessage"] as? String
        isUpdateRequired = AppVersion.isVersion(installedVersion, olderThan: minimumVersion)
        if isUpdateRequired {
            AppLogger.debug("[AppVersionService] Update required: \(installedVersion) < \(minimumVersion)")
        }
    }
}

/// Version string comparison ("1.2.10" is newer than "1.2.9", "1.2" equals "1.2.0")
enum AppVersion {
    static func isVersion(_ version: String, olderThan other: String) -> Bool {
        let lhs = components(of: version)
        let rhs = components(of: other)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }

    private static func components(of version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespaces)
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }
}
