import Foundation
import CoreGraphics

enum PracticeMode: String, Codable, CaseIterable, Identifiable {
    case trace
    case ghost
    case memory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trace: return "Trace"
        case .ghost: return "Ghost"
        case .memory: return "Memory"
        }
    }
}

enum PracticeStage: Int, Codable, CaseIterable, Identifiable {
    case guidedTrace
    case dotGuided
    case freePractice

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .guidedTrace: return "Trace"
        case .dotGuided: return "Trace with Dots"
        case .freePractice: return "Free Practice"
        }
    }
}

struct TipMessage: Identifiable, Equatable, Codable {
    let id: String
    let text: String

    static let catalog: [String: String] = [
        "start-point": "Begin where the green dot appears.",
        "stroke-order": "Follow the strokes in the order shown.",
        "direction": "Match the stroke direction.",
        "shape-tighten": "Stay closer to the letter shape."
    ]
}

struct StageOutcome {
    let stage: PracticeStage
    let score: ScoreResult
    let tips: [TipMessage]
    let duration: TimeInterval
}

struct RowMetrics: Equatable {
    let ascender: CGFloat
    let descender: CGFloat
}

enum StrokeSizePreference: String, Codable, CaseIterable, Identifiable {
    case large
    case standard
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .large: return "Large"
        case .standard: return "Standard"
        case .compact: return "Compact"
        }
    }

    var description: String {
        switch self {
        case .large: return "Biggest letters"
        case .standard: return "Default size"
        case .compact: return "Smaller letters"
        }
    }

    var metrics: RowMetrics {
        switch self {
        case .large:
            return RowMetrics(ascender: 150, descender: 80)
        case .standard:
            return RowMetrics(ascender: 120, descender: 60)
        case .compact:
            return RowMetrics(ascender: 100, descender: 50)
        }
    }
}

enum InputPreference: String, Codable, CaseIterable, Identifiable {
    case pencilOnly
    case fingerAndPencil

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pencilOnly:
            return "Apple Pencil Only"
        case .fingerAndPencil:
            return "Finger & Pencil"
        }
    }

    var allowsFingerInput: Bool {
        switch self {
        case .pencilOnly:
            return false
        case .fingerAndPencil:
            return true
        }
    }
}

struct ScoreResult: Codable, Equatable {
    let total: Int
    let shape: Int
    let order: Int
    let direction: Int
    let start: Int
}

struct LetterAttemptRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let letterId: String
    let mode: PracticeMode
    let score: ScoreResult
    let tips: [String]
    let hintUsed: Bool
    let rawDrawing: Data?
    let durationMs: Int
    let startedAt: Date
    let completedAt: Date
}

struct LetterMasteryRecord: Codable, Equatable {
    let letterId: String
    var bestScore: Int
    var bestMode: PracticeMode?
    var attemptCount: Int
    var lastPracticedAt: Date?
    var memoryPassCount: Int
    var unlocked: Bool

    mutating func registerAttempt(score: ScoreResult, mode: PracticeMode, date: Date) {
        attemptCount += 1
        lastPracticedAt = date
        if score.total > bestScore {
            bestScore = score.total
            bestMode = mode
        }
        if mode == .memory, score.total >= 80 {
            memoryPassCount += 1
        }
    }
}

struct PracticeDataSnapshot: Codable {
    var attempts: [LetterAttemptRecord]
    var mastery: [LetterMasteryRecord]
    var settings: UserSettings?
    var contentVersion: String?
    var flowOutcomes: [LetterFlowOutcome]?
}

struct UnlockEvent: Equatable {
    let newlyUnlockedLetterId: String
}

struct UserSettings: Codable, Equatable {
    var isLeftHanded: Bool
    var hapticsEnabled: Bool
    var inputPreference: InputPreference
    var strokeSize: StrokeSizePreference

    enum CodingKeys: String, CodingKey {
        case isLeftHanded
        case hapticsEnabled
        case inputPreference
        case strokeSize
    }

    init(isLeftHanded: Bool,
         hapticsEnabled: Bool,
         inputPreference: InputPreference,
         strokeSize: StrokeSizePreference) {
        self.isLeftHanded = isLeftHanded
        self.hapticsEnabled = hapticsEnabled
        self.inputPreference = inputPreference
        self.strokeSize = strokeSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let isLeftHanded = try container.decodeIfPresent(Bool.self, forKey: .isLeftHanded) ?? false
        let hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        let inputPreference = try container.decodeIfPresent(InputPreference.self, forKey: .inputPreference) ?? .fingerAndPencil
        let strokeSize = try container.decodeIfPresent(StrokeSizePreference.self, forKey: .strokeSize) ?? .standard
        self.init(isLeftHanded: isLeftHanded,
                  hapticsEnabled: hapticsEnabled,
                  inputPreference: inputPreference,
                  strokeSize: strokeSize)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isLeftHanded, forKey: .isLeftHanded)
        try container.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try container.encode(inputPreference, forKey: .inputPreference)
        try container.encode(strokeSize, forKey: .strokeSize)
    }

    static let `default` = UserSettings(isLeftHanded: false,
                                        hapticsEnabled: true,
                                        inputPreference: .fingerAndPencil,
                                        strokeSize: .standard)
}

struct StageAttemptSummary: Codable, Equatable {
    let stage: PracticeStage
    let score: ScoreResult
    let durationMs: Int
}

struct LetterFlowOutcome: Codable, Equatable {
    let letterId: String
    let aggregatedScore: ScoreResult
    let stageSummaries: [StageAttemptSummary]
    let completedAt: Date
}
