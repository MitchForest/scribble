import UIKit

protocol HapticsProviding {
    func warning()
    func success()
    func notice(intensity: CGFloat)
}

@MainActor
final class SystemHapticsProvider: HapticsProviding {
    static let shared = SystemHapticsProvider()

    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)

    private init() {
        notificationGenerator.prepare()
        impactGenerator.prepare()
    }

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
