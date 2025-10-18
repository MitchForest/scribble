import Foundation
import Combine

/// Top-level view model for the lesson practice screen.
/// Responsible for exposing read-only state to the SwiftUI view hierarchy and delegating
/// orchestration responsibilities to `PracticeSessionController`.
final class LessonPracticeViewModel: ObservableObject {
    @Published private(set) var sessionState: PracticeSessionController.State

    private let controller: PracticeSessionController
    private var cancellables: Set<AnyCancellable> = []

    init(controller: PracticeSessionController) {
        self.controller = controller
        self.sessionState = controller.state
        bindController()
    }

    func handle(event: PracticeSessionController.Event) {
        controller.handle(event)
    }

    private func bindController() {
        controller.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.sessionState = newState
            }
            .store(in: &cancellables)
    }
}
