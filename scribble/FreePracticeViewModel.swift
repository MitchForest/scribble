import Foundation
import PencilKit

@MainActor
final class FreePracticeViewModel: ObservableObject {
    @Published var targetText: String {
        didSet {
            if targetText != oldValue {
                scheduleTimelineUpdate()
            }
        }
    }

    @Published private(set) var timeline: [LetterTimelineItem] = []
    @Published private(set) var letterStates: [LetterState] = []
    @Published private(set) var currentLetterIndex: Int = 0

    init(initialText: String = "a a a") {
        self.targetText = initialText
        scheduleTimelineUpdate()
    }

    var currentLetter: LetterTimelineItem? {
        timeline[safe: currentLetterIndex]
    }

    func jump(to index: Int) {
        guard timeline.indices.contains(index),
              timeline[index].isPractiseable else { return }
        currentLetterIndex = index
    }

    func markWarningForCurrentLetter() {
        guard letterStates.indices.contains(currentLetterIndex) else { return }
        letterStates[currentLetterIndex].hadWarning = true
    }

    func markLetterCompleted() {
        guard letterStates.indices.contains(currentLetterIndex) else { return }
        letterStates[currentLetterIndex].isComplete = true
        letterStates[currentLetterIndex].hadWarning = false
    }

    func advanceToNextPractiseableLetter() {
        guard !timeline.isEmpty else { return }
        var nextIndex = currentLetterIndex + 1
        while nextIndex < timeline.count {
            if timeline[nextIndex].isPractiseable {
                currentLetterIndex = nextIndex
                return
            } else {
                letterStates[nextIndex].isComplete = true
                nextIndex += 1
            }
        }
        currentLetterIndex = min(timeline.count - 1, currentLetterIndex)
    }

    func resumeIfNeeded() {
        if timeline.isEmpty {
            scheduleTimelineUpdate()
        }
    }

    private func scheduleTimelineUpdate() {
        let items = FreePracticeViewModel.buildTimeline(for: targetText)
        applyTimeline(items: items)
    }

    private func applyTimeline(items: [LetterTimelineItem]) {
        timeline = items
        letterStates = items.map { item in
            var state = LetterState()
            if !item.isPractiseable {
                state.isComplete = true
            }
            return state
        }

        if let firstPractiseable = items.firstIndex(where: { $0.isPractiseable }) {
            currentLetterIndex = firstPractiseable
        } else {
            currentLetterIndex = 0
        }
    }

    private static func buildTimeline(for text: String) -> [LetterTimelineItem] {
        guard !text.isEmpty else { return [] }
        return text.map { character -> LetterTimelineItem in
            if character.isWhitespace {
                return LetterTimelineItem(character: character,
                                          letterId: nil,
                                          template: nil,
                                          support: .space)
            }
            if let letterId = Self.letterId(for: character) {
                let template = try? HandwritingTemplateLoader.loadTemplate(for: letterId)
                if let template {
                    return LetterTimelineItem(character: character,
                                              letterId: letterId,
                                              template: template,
                                              support: .supported)
                } else {
                    return LetterTimelineItem(character: character,
                                              letterId: letterId,
                                              template: nil,
                                              support: .unsupported)
                }
            }
            return LetterTimelineItem(character: character,
                                      letterId: nil,
                                      template: nil,
                                      support: .unsupported)
        }
    }

    private static func letterId(for character: Character) -> String? {
        if character.isLetter {
            if character.isUppercase {
                return "\(character).upper"
            } else {
                return "\(character).lower"
            }
        }
        return nil
    }
}

struct LetterState: Identifiable {
    let id = UUID()
    var hadWarning: Bool = false
    var isComplete: Bool = false
}

struct LetterTimelineItem: Identifiable {
    enum Support {
        case supported
        case space
        case unsupported
    }

    let id = UUID()
    let character: Character
    let letterId: String?
    let template: HandwritingTemplate?
    let support: Support

    var isSpace: Bool {
        support == .space
    }

    var isPractiseable: Bool {
        support == .supported && template != nil
    }

    var strokeCount: Int {
        template?.strokes.count ?? 0
    }
}
