import Foundation

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

/// Represents the writing state for an individual row/letter combination used by the session controller.
struct RowState {
    enum Phase {
        case previewing
        case writing
        case frozen
    }

    var phase: Phase
    var didCompleteLetter: Bool

    init(phase: Phase, didCompleteLetter: Bool = false) {
        self.phase = phase
        self.didCompleteLetter = didCompleteLetter
    }
}
