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

enum PracticeDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
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
            return RowMetrics(ascender: 190, descender: 110)
        case .standard:
            return RowMetrics(ascender: 150, descender: 85)
        case .compact:
            return RowMetrics(ascender: 120, descender: 60)
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

struct PracticeGoal: Codable, Equatable {
    var dailyXP: Int
    var activeDaysPerWeek: Int

    static let defaultGoal = PracticeGoal(dailyXP: 100, activeDaysPerWeek: 5)
}

struct UserProfile: Codable, Equatable {
    var displayName: String
    var avatarSeed: String
    var goal: PracticeGoal

    static let `default` = UserProfile(displayName: "Explorer",
                                       avatarSeed: "storybook",
                                       goal: .defaultGoal)
}

struct XPEvent: Codable, Identifiable, Equatable {
    enum Category: String, Codable {
        case practiceStroke
        case practiceLine
        case sessionBonus
        case custom
    }

    let id: UUID
    let amount: Int
    let createdAt: Date
    let category: Category
    let letterId: String?
    let note: String?

    init(id: UUID = UUID(),
         amount: Int,
         createdAt: Date = Date(),
         category: Category,
         letterId: String? = nil,
         note: String? = nil) {
        self.id = id
        self.amount = amount
        self.createdAt = createdAt
        self.category = category
        self.letterId = letterId
        self.note = note
    }
}

struct ContributionDay: Identifiable, Equatable {
    let date: Date
    let xpEarned: Int
    let goalXP: Int

    var id: Date { date }

    var didHitGoal: Bool {
        xpEarned >= goalXP && goalXP > 0
    }
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
    var profile: UserProfile?
    var xpEvents: [XPEvent]?
}

struct UnlockEvent: Equatable {
    let newlyUnlockedLetterId: String
}

struct UserSettings: Codable, Equatable {
    var isLeftHanded: Bool
    var hapticsEnabled: Bool
    var inputPreference: InputPreference
    var strokeSize: StrokeSizePreference
    var difficulty: PracticeDifficulty

    enum CodingKeys: String, CodingKey {
        case isLeftHanded
        case hapticsEnabled
        case inputPreference
        case strokeSize
        case difficulty
    }

    init(isLeftHanded: Bool,
         hapticsEnabled: Bool,
         inputPreference: InputPreference,
         strokeSize: StrokeSizePreference,
         difficulty: PracticeDifficulty) {
        self.isLeftHanded = isLeftHanded
        self.hapticsEnabled = hapticsEnabled
        self.inputPreference = inputPreference
        self.strokeSize = strokeSize
        self.difficulty = difficulty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let isLeftHanded = try container.decodeIfPresent(Bool.self, forKey: .isLeftHanded) ?? false
        let hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        let inputPreference = try container.decodeIfPresent(InputPreference.self, forKey: .inputPreference) ?? .pencilOnly
        let strokeSize = try container.decodeIfPresent(StrokeSizePreference.self, forKey: .strokeSize) ?? .standard
        let difficulty = try container.decodeIfPresent(PracticeDifficulty.self, forKey: .difficulty) ?? .medium
        self.init(isLeftHanded: isLeftHanded,
                  hapticsEnabled: hapticsEnabled,
                  inputPreference: inputPreference,
                  strokeSize: strokeSize,
                  difficulty: difficulty)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isLeftHanded, forKey: .isLeftHanded)
        try container.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try container.encode(inputPreference, forKey: .inputPreference)
        try container.encode(strokeSize, forKey: .strokeSize)
        try container.encode(difficulty, forKey: .difficulty)
    }

    static let `default` = UserSettings(isLeftHanded: false,
                                        hapticsEnabled: true,
                                        inputPreference: .pencilOnly,
                                        strokeSize: .standard,
                                        difficulty: .medium)
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
