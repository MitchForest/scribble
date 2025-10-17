import UIKit

final class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)

    func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    func notice() {
        impactGenerator.impactOccurred(intensity: 0.5)
    }
}
