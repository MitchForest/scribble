import Foundation

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
}

struct UnlockEvent: Equatable {
    let newlyUnlockedLetterId: String
}

struct UserSettings: Codable, Equatable {
    var isLeftHanded: Bool
    var hapticsEnabled: Bool

    static let `default` = UserSettings(isLeftHanded: false, hapticsEnabled: true)
}
