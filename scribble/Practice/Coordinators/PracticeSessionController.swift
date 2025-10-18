import Combine
import Foundation
import PencilKit

/// Coordinates practice repetitions, row progression, and overall lesson flow.
/// Acts as the single source of truth for per-row state so the UI can remain declarative.
final class PracticeSessionController {
    struct State {
        var repetitions: [RepetitionState]
        var activeRepetitionIndex: Int
        var activeLetterGlobalIndex: Int
        var totalLetters: Int
        var lesson: PracticeLesson
        var settings: UserSettings
        var timeline: PracticeTimeline
    }

    enum Event {
        case start
        case letterCompleted(repetition: Int, letterIndex: Int)
        case replay(letterIndex: Int)
        case clearAll
        case updateSettings(UserSettings)
        case updateTimeline(PracticeTimeline)
        case rowEvent(RowEvent)
    }

    enum RowEvent {
        case previewStarted(repetition: Int, letterIndex: Int)
        case previewProgressed(repetition: Int, letterIndex: Int, progress: [CGFloat])
        case previewCompleted(repetition: Int, letterIndex: Int)
        case drawingChanged(repetition: Int, letterIndex: Int, drawing: PKDrawing)
        case liveSamplesUpdated(repetition: Int, letterIndex: Int, samples: [CanvasStrokeSample])
        case warningUpdated(repetition: Int, letterIndex: Int, message: String?)
    }

    private(set) var state: State
    private let stateSubject: CurrentValueSubject<State, Never>

    var statePublisher: AnyPublisher<State, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    init(lesson: PracticeLesson,
         settings: UserSettings,
         timeline: PracticeTimeline,
         repetitions: Int) {
        let repetitionStates = (0..<repetitions).map { _ in
            RepetitionState(letters: timeline.items, activeLetterIndex: 0)
        }
        let state = State(repetitions: repetitionStates,
                          activeRepetitionIndex: 0,
                          activeLetterGlobalIndex: 0,
                          totalLetters: timeline.totalPractiseableLetters,
                          lesson: lesson,
                          settings: settings,
                          timeline: timeline)
        self.state = state
        self.stateSubject = CurrentValueSubject(state)
    }

    func handle(_ event: Event) {
        switch event {
        case .start:
            startSessionIfNeeded()
        case let .letterCompleted(repetition, letterIndex):
            advanceAfterLetterCompletion(repetition: repetition, letterIndex: letterIndex)
        case let .replay(letterIndex):
            replayLetter(at: letterIndex)
        case .clearAll:
            resetAll()
        case let .updateSettings(settings):
            updateSettings(settings)
        case let .updateTimeline(timeline):
            updateTimeline(timeline)
        case let .rowEvent(rowEvent):
            handleRowEvent(rowEvent)
        }
    }

    private func startSessionIfNeeded() {
        guard state.repetitions.isEmpty == false else { return }
        var newState = state
        for index in newState.repetitions.indices {
            newState.repetitions[index].updateActiveLetter(to: newState.activeLetterGlobalIndex)
        }
        state = newState
        stateSubject.send(newState)
    }

    private func advanceAfterLetterCompletion(repetition: Int, letterIndex: Int) {
        guard state.repetitions.indices.contains(repetition) else { return }
        guard state.repetitions[repetition].letters.indices.contains(letterIndex) else { return }
        var newState = state
        let repetitionCount = newState.repetitions.count
        let activeLetter = newState.activeLetterGlobalIndex

        newState.repetitions[repetition].markLetterCompleted(at: letterIndex)

        if repetition + 1 < repetitionCount {
            let nextRepetition = repetition + 1
            newState.activeRepetitionIndex = nextRepetition
            newState.repetitions[nextRepetition].updateActiveLetter(to: activeLetter)
        } else {
            let nextLetter = activeLetter + 1
            newState.activeLetterGlobalIndex = min(nextLetter, max(newState.totalLetters - 1, 0))
            newState.activeRepetitionIndex = 0
            for index in newState.repetitions.indices {
                newState.repetitions[index].updateActiveLetter(to: newState.activeLetterGlobalIndex)
            }
        }

        state = newState
        stateSubject.send(newState)
    }

    private func replayLetter(at index: Int) {
        guard state.timeline.items.indices.contains(index) else { return }
        var newState = state
        newState.activeLetterGlobalIndex = index
        newState.activeRepetitionIndex = 0

        for repetitionIndex in newState.repetitions.indices {
            newState.repetitions[repetitionIndex] = RepetitionState(letters: state.timeline.items,
                                                                    activeLetterIndex: index)
        }

        state = newState
        stateSubject.send(newState)
    }

    private func resetAll() {
        var newState = state
        newState.activeRepetitionIndex = 0
        newState.activeLetterGlobalIndex = 0
        newState.repetitions = Array(repeating: RepetitionState(letters: state.timeline.items, activeLetterIndex: 0), count: newState.repetitions.count)
        state = newState
        stateSubject.send(newState)
    }

    private func updateSettings(_ settings: UserSettings) {
        var newState = state
        newState.settings = settings
        state = newState
        stateSubject.send(newState)
    }

    private func updateTimeline(_ timeline: PracticeTimeline) {
        var newState = state
        newState.timeline = timeline
        newState.totalLetters = timeline.totalPractiseableLetters
        newState.activeLetterGlobalIndex = 0
        newState.activeRepetitionIndex = 0
        newState.repetitions = Array(repeating: RepetitionState(letters: timeline.items, activeLetterIndex: 0), count: newState.repetitions.count)
        state = newState
        stateSubject.send(newState)
    }

    private func handleRowEvent(_ event: RowEvent) {
        switch event {
        case let .previewStarted(repetition, letterIndex):
            updateRow(repetition: repetition, letterIndex: letterIndex) { row in
                row.phase = .previewing
                row.previewGeneration &+= 1
                row.previewProgress = []
            }
        case let .previewProgressed(repetition, letterIndex, progress):
            updateRow(repetition: repetition, letterIndex: letterIndex) { row in
                row.previewProgress = progress
            }
        case let .previewCompleted(repetition, letterIndex):
            updateRow(repetition: repetition, letterIndex: letterIndex) { row in
                row.phase = .writing
                row.previewProgress = []
            }
        case let .drawingChanged(repetition, letterIndex, drawing):
            updateRow(repetition: repetition, letterIndex: letterIndex) { row in
                row.drawing = drawing
            }
        case let .liveSamplesUpdated(repetition, letterIndex, samples):
            updateRow(repetition: repetition, letterIndex: letterIndex) { row in
                row.activeStrokeSamples = samples
            }
        case let .warningUpdated(repetition, letterIndex, message):
            updateRow(repetition: repetition, letterIndex: letterIndex) { row in
                row.warningMessage = message
                row.lastWarningTime = message == nil ? row.lastWarningTime : Date()
            }
        }
    }

    private func updateRow(repetition: Int, letterIndex: Int, mutate: (inout RowState) -> Void) {
        guard state.repetitions.indices.contains(repetition) else { return }
        guard state.repetitions[repetition].rows.indices.contains(letterIndex) else { return }
        var newState = state
        mutate(&newState.repetitions[repetition].rows[letterIndex])
        state = newState
        stateSubject.send(newState)
    }
}
