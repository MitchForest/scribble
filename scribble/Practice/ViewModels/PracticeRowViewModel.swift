import Combine
import Foundation
import PencilKit

/// View-model wrapper for a single row's state, derived from `PracticeSessionController`.
final class PracticeRowViewModel: ObservableObject {
    @Published private(set) var state: RowState

    private let repetitionIndex: Int
    private let controller: PracticeSessionController
    private var cancellables: Set<AnyCancellable> = []

    init(repetitionIndex: Int,
         controller: PracticeSessionController) {
        self.repetitionIndex = repetitionIndex
        self.controller = controller
        self.state = controller.state.repetitions[safe: repetitionIndex]?.rows[safe: controller.state.activeLetterGlobalIndex] ?? RowState(phase: .frozen)
        bind()
    }

    func handlePreviewStart(for letterIndex: Int) {
        controller.handle(.rowEvent(.previewStarted(repetition: repetitionIndex, letterIndex: letterIndex)))
    }

    func handlePreviewProgress(for letterIndex: Int, progress: [CGFloat]) {
        controller.handle(.rowEvent(.previewProgressed(repetition: repetitionIndex,
                                                       letterIndex: letterIndex,
                                                       progress: progress)))
    }

    func handlePreviewCompleted(for letterIndex: Int) {
        controller.handle(.rowEvent(.previewCompleted(repetition: repetitionIndex, letterIndex: letterIndex)))
    }

    func handleDrawingChanged(_ drawing: PKDrawing, letterIndex: Int) {
        controller.handle(.rowEvent(.drawingChanged(repetition: repetitionIndex,
                                                    letterIndex: letterIndex,
                                                    drawing: drawing)))
    }

    func handleLiveSamples(_ samples: [CanvasStrokeSample], letterIndex: Int) {
        controller.handle(.rowEvent(.liveSamplesUpdated(repetition: repetitionIndex,
                                                        letterIndex: letterIndex,
                                                        samples: samples)))
    }

    func handleWarning(message: String?, letterIndex: Int) {
        controller.handle(.rowEvent(.warningUpdated(repetition: repetitionIndex,
                                                    letterIndex: letterIndex,
                                                    message: message)))
    }

    private func bind() {
        controller.statePublisher
            .map { state in
                state.repetitions[safe: self.repetitionIndex]?.rows[safe: state.activeLetterGlobalIndex] ?? RowState(phase: .frozen)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rowState in
                self?.state = rowState
            }
            .store(in: &cancellables)
    }
}
