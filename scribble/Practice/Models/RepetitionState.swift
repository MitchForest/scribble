import Foundation
import PencilKit

/// Represents captured live stroke samples for diagnostics and incremental validation.
typealias CanvasStrokeSamples = [CanvasStrokeSample]

/// Captures state for a single practice repetition (row) across the lesson timeline.
struct RepetitionState {
    var letters: [LetterTimelineItem]
    var activeLetterIndex: Int
    var rows: [RowState]

    init(letters: [LetterTimelineItem], activeLetterIndex: Int = 0) {
        self.letters = letters
        let clampedIndex = min(max(activeLetterIndex, 0), max(letters.count - 1, 0))
        self.activeLetterIndex = clampedIndex
        self.rows = letters.enumerated().map { index, letter in
            let phase: RowState.Phase
            if letter.isPractiseable {
                phase = index == clampedIndex ? .previewing : .frozen
            } else {
                phase = .frozen
            }
            return RowState(phase: phase)
        }
    }

    mutating func updateActiveLetter(to newIndex: Int) {
        guard letters.indices.contains(newIndex) else { return }
        activeLetterIndex = newIndex
        for index in rows.indices {
            guard letters[index].isPractiseable else {
                rows[index].phase = .frozen
                continue
            }
            if index < newIndex {
                rows[index].phase = .frozen
                rows[index].didCompleteLetter = true
            } else if index == newIndex {
                rows[index].phase = .previewing
            } else {
                rows[index].phase = .frozen
            }
        }
    }

    mutating func markLetterCompleted(at index: Int) {
        guard rows.indices.contains(index) else { return }
        rows[index].didCompleteLetter = true
        rows[index].phase = .frozen
    }
}

/// Represents the writing state for an individual row/letter combination.
struct RowState {
    enum Phase {
        case previewing
        case writing
        case frozen
    }

    var phase: Phase
    var drawing: PKDrawing
    var frozenDrawing: PKDrawing
    var warningMessage: String?
    var currentStrokeIndex: Int
    var lastWarningTime: Date?
    var completedCheckpointCount: Int
    var completedStrokeCount: Int
    var didCompleteLetter: Bool
    var previewProgress: [CGFloat]
    var previewGeneration: Int
    var celebrationVisible: Bool
    var celebrationToken: Int
    var activeStrokeSamples: CanvasStrokeSamples
    var lastIgnoreReason: String?

    init(phase: Phase,
         drawing: PKDrawing = PKDrawing(),
         frozenDrawing: PKDrawing = PKDrawing(),
         warningMessage: String? = nil,
         currentStrokeIndex: Int = 0,
         lastWarningTime: Date? = nil,
         completedCheckpointCount: Int = 0,
         completedStrokeCount: Int = 0,
         didCompleteLetter: Bool = false,
         previewProgress: [CGFloat] = [],
         previewGeneration: Int = 0,
         celebrationVisible: Bool = false,
         celebrationToken: Int = 0,
         activeStrokeSamples: CanvasStrokeSamples = [],
         lastIgnoreReason: String? = nil) {
        self.phase = phase
        self.drawing = drawing
        self.frozenDrawing = frozenDrawing
        self.warningMessage = warningMessage
        self.currentStrokeIndex = currentStrokeIndex
        self.lastWarningTime = lastWarningTime
        self.completedCheckpointCount = completedCheckpointCount
        self.completedStrokeCount = completedStrokeCount
        self.didCompleteLetter = didCompleteLetter
        self.previewProgress = previewProgress
        self.previewGeneration = previewGeneration
        self.celebrationVisible = celebrationVisible
        self.celebrationToken = celebrationToken
        self.activeStrokeSamples = activeStrokeSamples
        self.lastIgnoreReason = lastIgnoreReason
    }

    var isWriting: Bool { phase == .writing }
    var isPreviewing: Bool { phase == .previewing }
    var isFrozen: Bool { phase == .frozen }
}
