import Foundation

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

    var isSpace: Bool { support == .space }

    var isPractiseable: Bool { support == .supported && template != nil }

    var strokeCount: Int { template?.strokes.count ?? 0 }
}
