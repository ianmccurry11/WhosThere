//
//  ShakeDetector.swift
//  WhosThereios
//
//  Created by Ian McCurry on 2/22/26.
//

import SwiftUI
import UIKit

// MARK: - Shake Gesture Detection

/// A UIKit shim that detects device shake and fires a notification.
/// Usage: attach `.onShake { }` to any SwiftUI view.
extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

/// View modifier that reacts to device shakes.
struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

extension View {
    /// Perform an action when the user shakes the device.
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}
