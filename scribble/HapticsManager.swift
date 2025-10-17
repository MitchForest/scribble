import UIKit

@MainActor
final class HapticsManager {
    static let shared = HapticsManager()
    private init() {
        notificationGenerator.prepare()
        impactGenerator.prepare()
    }

    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)

    func warning() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }

    func success() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }

    func notice(intensity: CGFloat = 0.75) {
        impactGenerator.prepare()
        impactGenerator.impactOccurred(intensity: intensity)
    }
}
