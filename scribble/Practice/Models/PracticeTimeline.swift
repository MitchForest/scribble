import Foundation

/// Represents the ordered collection of letters (and whitespace) used for a practice session.
struct PracticeTimeline {
    let items: [LetterTimelineItem]
    let practiseableIndices: [Int]

    var totalPractiseableLetters: Int {
        practiseableIndices.count
    }

    static let empty = PracticeTimeline(items: [], practiseableIndices: [])
}

enum PracticeTimelineBuilder {
    static func build(from text: String) -> PracticeTimeline {
        guard text.isEmpty == false else { return .empty }

        var items: [LetterTimelineItem] = []
        var practiseable: [Int] = []

        for (index, character) in text.enumerated() {
            let item = makeItem(for: character)
            items.append(item)
            if item.isPractiseable {
                practiseable.append(index)
            }
        }

        return PracticeTimeline(items: items,
                                practiseableIndices: practiseable)
    }

    private static func makeItem(for character: Character) -> LetterTimelineItem {
        if character.isWhitespace {
            return LetterTimelineItem(character: character,
                                      letterId: nil,
                                      template: nil,
                                      support: .space)
        }

        guard let letterId = letterId(for: character) else {
            return LetterTimelineItem(character: character,
                                      letterId: nil,
                                      template: nil,
                                      support: .unsupported)
        }

        if let template = try? HandwritingTemplateLoader.loadTemplate(for: letterId) {
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

    private static func letterId(for character: Character) -> String? {
        guard character.isLetter else { return nil }
        if character.isUppercase {
            return "\(character).upper"
        } else {
            return "\(character).lower"
        }
    }
}
