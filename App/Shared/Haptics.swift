#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Gentle, sound-free feedback on both platforms.
@MainActor
enum Haptics {
    static func tap() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #else
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func success() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #else
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func select() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #else
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
