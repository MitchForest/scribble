import Combine
import Foundation

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
}
