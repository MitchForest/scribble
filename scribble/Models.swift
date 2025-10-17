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

enum PracticeDifficulty: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case expert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .expert: return "Expert"
        }
    }
}

struct PracticeDifficultyProfile {
    enum HapticStyle {
        case none
        case soft
        case warning
    }

    let strokeSize: StrokeSizePreference
    let corridorWidthMultiplier: CGFloat
    let corridorSoftness: CGFloat
    let startToleranceMultiplier: CGFloat
    let deviationToleranceMultiplier: CGFloat
    let startSnapMultiplier: CGFloat
    let warningCooldown: TimeInterval
    let preservesMistakeStroke: Bool
    let hapticStyle: HapticStyle
    let directionSlackDegrees: CGFloat
    let mergedStrokeAllowance: Int
    let evaluationTighteningRate: CGFloat
    let showsGuides: Bool
    let completionCoverageThreshold: Double
    let startForgivenessMultiplier: CGFloat
}

extension PracticeDifficulty {
    var profile: PracticeDifficultyProfile {
        switch self {
        case .beginner:
            return PracticeDifficultyProfile(
                strokeSize: .large,
                corridorWidthMultiplier: 1.45,
                corridorSoftness: 18,
                startToleranceMultiplier: 1.7,
                deviationToleranceMultiplier: 1.55,
                startSnapMultiplier: 1.15,
                warningCooldown: 2.2,
                preservesMistakeStroke: true,
                hapticStyle: .none,
                directionSlackDegrees: 35,
                mergedStrokeAllowance: 2,
                evaluationTighteningRate: 0.35,
                showsGuides: true,
                completionCoverageThreshold: 0.65,
                startForgivenessMultiplier: 2.4
            )
        case .intermediate:
            return PracticeDifficultyProfile(
                strokeSize: .standard,
                corridorWidthMultiplier: 1.05,
                corridorSoftness: 12,
                startToleranceMultiplier: 1.05,
                deviationToleranceMultiplier: 1.0,
                startSnapMultiplier: 0.85,
                warningCooldown: 1.6,
                preservesMistakeStroke: true,
                hapticStyle: .soft,
                directionSlackDegrees: 24,
                mergedStrokeAllowance: 1,
                evaluationTighteningRate: 0.55,
                showsGuides: true,
                completionCoverageThreshold: 0.75,
                startForgivenessMultiplier: 1.7
            )
        case .expert:
            return PracticeDifficultyProfile(
                strokeSize: .compact,
                corridorWidthMultiplier: 0.7,
                corridorSoftness: 8,
                startToleranceMultiplier: 0.7,
                deviationToleranceMultiplier: 0.68,
                startSnapMultiplier: 0.6,
                warningCooldown: 1.0,
                preservesMistakeStroke: false,
                hapticStyle: .warning,
                directionSlackDegrees: 15,
                mergedStrokeAllowance: 0,
                evaluationTighteningRate: 0.75,
                showsGuides: false,
                completionCoverageThreshold: 0.85,
                startForgivenessMultiplier: 1.3
            )
        }
    }
}

extension PracticeDifficultyProfile {
    func validationConfiguration(rowHeight: CGFloat,
                                  visualStartRadius: CGFloat,
                                  userInkWidth: CGFloat) -> RasterStrokeValidator.Configuration {
        let defaults = RasterValidationDefaults.configuration(for: self)
        let tubeRadius = max(rowHeight * defaults.tubeFactor, RasterValidationDefaults.minimumTubeRadius)
        let tubeLineWidth = tubeRadius * 2
        let studentLineWidth = tubeLineWidth * defaults.studentWidthMultiplier
        let startRadius = max(visualStartRadius,
                              tubeRadius * RasterValidationDefaults.startZoneRadiusMultiplier)

        return RasterStrokeValidator.Configuration(rasterScale: RasterValidationDefaults.rasterScale,
                                                   tubeLineWidth: tubeLineWidth,
                                                   studentLineWidth: studentLineWidth,
                                                   startRadius: startRadius,
                                                   coverageThreshold: defaults.coverageThreshold)
    }
}

private enum RasterValidationDefaults {
    struct DifficultyConfiguration {
        let tubeFactor: CGFloat
        let studentWidthMultiplier: CGFloat
        let coverageThreshold: Double
    }

    static let rasterScale: CGFloat = 2
    static let minimumTubeRadius: CGFloat = 3
    static let startZoneRadiusMultiplier: CGFloat = 1.6

    private static let beginner = DifficultyConfiguration(tubeFactor: 0.12,
                                                          studentWidthMultiplier: 1.4,
                                                          coverageThreshold: 0.9)

    private static let intermediate = DifficultyConfiguration(tubeFactor: 0.085,
                                                              studentWidthMultiplier: 1.2,
                                                              coverageThreshold: 0.94)

    private static let expert = DifficultyConfiguration(tubeFactor: 0.05,
                                                        studentWidthMultiplier: 1.1,
                                                        coverageThreshold: 0.97)

    static func configuration(for profile: PracticeDifficultyProfile) -> DifficultyConfiguration {
        switch profile.strokeSize {
        case .large:
            return beginner
        case .standard:
            return intermediate
        case .compact:
            return expert
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
    static let secondsPerLetter = 5
    static let defaultActiveWeekdays: Set<Int> = [0, 1, 2, 3, 4] // Monday–Friday

    var dailySeconds: Int {
        didSet {
            dailySeconds = max(dailySeconds, PracticeGoal.secondsPerLetter)
        }
    }

    private var storedActiveDaysPerWeek: Int
    private var storedActiveWeekdayIndices: Set<Int>

    var activeDaysPerWeek: Int {
        get {
            let count = activeWeekdayIndices.count
            return count > 0 ? count : storedActiveDaysPerWeek
        }
        set {
            storedActiveDaysPerWeek = PracticeGoal.clampDays(newValue)
            if storedActiveWeekdayIndices.count != storedActiveDaysPerWeek {
                storedActiveWeekdayIndices = PracticeGoal.defaultWeekdaySet(forCount: storedActiveDaysPerWeek)
            }
        }
    }

    var activeWeekdayIndices: Set<Int> {
        get {
            if storedActiveWeekdayIndices.isEmpty {
                return PracticeGoal.defaultWeekdaySet(forCount: storedActiveDaysPerWeek)
            }
            return storedActiveWeekdayIndices
        }
        set {
            let sanitized = PracticeGoal.sanitizeWeekdaySet(newValue)
            if sanitized.isEmpty {
                storedActiveWeekdayIndices = PracticeGoal.defaultWeekdaySet(forCount: storedActiveDaysPerWeek)
            } else {
                storedActiveWeekdayIndices = sanitized
                storedActiveDaysPerWeek = sanitized.count
            }
        }
    }

    var dailyLetterGoal: Int {
        max(dailySeconds / PracticeGoal.secondsPerLetter, 1)
    }

    static let defaultGoal = PracticeGoal(dailySeconds: 300,
                                          activeDaysPerWeek: 5,
                                          activeWeekdayIndices: PracticeGoal.defaultActiveWeekdays)

    private enum CodingKeys: String, CodingKey {
        case dailySeconds
        case activeDaysPerWeek
        case activeWeekdayIndices
        case dailyXP // legacy
    }

    init(dailySeconds: Int,
         activeDaysPerWeek: Int,
         activeWeekdayIndices: Set<Int>? = nil) {
        self.dailySeconds = max(dailySeconds, PracticeGoal.secondsPerLetter)
        let clampedDays = PracticeGoal.clampDays(activeDaysPerWeek)
        self.storedActiveDaysPerWeek = clampedDays
        if let indices = activeWeekdayIndices {
            let sanitized = PracticeGoal.sanitizeWeekdaySet(indices)
            if sanitized.isEmpty {
                self.storedActiveWeekdayIndices = PracticeGoal.defaultWeekdaySet(forCount: clampedDays)
            } else {
                self.storedActiveWeekdayIndices = sanitized
                self.storedActiveDaysPerWeek = sanitized.count
            }
        } else {
            self.storedActiveWeekdayIndices = PracticeGoal.defaultWeekdaySet(forCount: clampedDays)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSeconds = try container.decodeIfPresent(Int.self, forKey: .dailySeconds)
            ?? container.decodeIfPresent(Int.self, forKey: .dailyXP)
            ?? 300
        self.dailySeconds = max(decodedSeconds, PracticeGoal.secondsPerLetter)

        let decodedDays = PracticeGoal.clampDays(
            try container.decodeIfPresent(Int.self, forKey: .activeDaysPerWeek) ?? 5
        )
        self.storedActiveDaysPerWeek = decodedDays

        if let indices = try container.decodeIfPresent([Int].self, forKey: .activeWeekdayIndices) {
            let sanitized = PracticeGoal.sanitizeWeekdaySet(Set(indices))
            if sanitized.isEmpty {
                self.storedActiveWeekdayIndices = PracticeGoal.defaultWeekdaySet(forCount: decodedDays)
            } else {
                self.storedActiveWeekdayIndices = sanitized
                self.storedActiveDaysPerWeek = sanitized.count
            }
        } else {
            self.storedActiveWeekdayIndices = PracticeGoal.defaultWeekdaySet(forCount: decodedDays)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dailySeconds, forKey: .dailySeconds)
        try container.encode(activeDaysPerWeek, forKey: .activeDaysPerWeek)
        try container.encode(Array(activeWeekdayIndices).sorted(), forKey: .activeWeekdayIndices)
    }

    private static func clampDays(_ value: Int) -> Int {
        min(max(value, 1), 7)
    }

    private static func defaultWeekdaySet(forCount count: Int) -> Set<Int> {
        let clamped = clampDays(count)
        return Set((0..<clamped).map { $0 })
    }

    private static func sanitizeWeekdaySet(_ set: Set<Int>) -> Set<Int> {
        Set(set.filter { (0...6).contains($0) })
    }
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
    let secondsSpent: Int
    let goalSeconds: Int

    var id: Date { date }

    var didHitGoal: Bool {
        goalSeconds > 0 && secondsSpent >= goalSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case secondsSpent
        case goalSeconds
        case xpEarned // legacy
        case goalXP // legacy
    }

    init(date: Date, secondsSpent: Int, goalSeconds: Int) {
        self.date = date
        self.secondsSpent = secondsSpent
        self.goalSeconds = goalSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        if let seconds = try container.decodeIfPresent(Int.self, forKey: .secondsSpent) {
            secondsSpent = seconds
        } else if let xp = try container.decodeIfPresent(Int.self, forKey: .xpEarned) {
            secondsSpent = xp
        } else {
            secondsSpent = 0
        }
        if let goal = try container.decodeIfPresent(Int.self, forKey: .goalSeconds) {
            goalSeconds = goal
        } else if let legacyGoal = try container.decodeIfPresent(Int.self, forKey: .goalXP) {
            goalSeconds = legacyGoal
        } else {
            goalSeconds = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(secondsSpent, forKey: .secondsSpent)
        try container.encode(goalSeconds, forKey: .goalSeconds)
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

struct LessonProgressRecord: Codable, Equatable {
    let lessonId: PracticeLesson.ID
    var completedLetters: Int
    var updatedAt: Date
}

struct PracticeDataSnapshot: Codable {
    var attempts: [LetterAttemptRecord]
    var mastery: [LetterMasteryRecord]
    var settings: UserSettings?
    var contentVersion: String?
    var profile: UserProfile?
    var xpEvents: [XPEvent]?
    var lessonProgress: [LessonProgressRecord]?
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
    var prefersGuides: Bool

    enum CodingKeys: String, CodingKey {
        case isLeftHanded
        case hapticsEnabled
        case inputPreference
        case strokeSize
        case difficulty
        case prefersGuides
    }

    init(isLeftHanded: Bool,
         hapticsEnabled: Bool,
         inputPreference: InputPreference,
         strokeSize: StrokeSizePreference,
         difficulty: PracticeDifficulty,
         prefersGuides: Bool) {
        self.isLeftHanded = isLeftHanded
        self.hapticsEnabled = hapticsEnabled
        self.inputPreference = inputPreference
        self.strokeSize = strokeSize
        self.difficulty = difficulty
        self.prefersGuides = prefersGuides
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let isLeftHanded = try container.decodeIfPresent(Bool.self, forKey: .isLeftHanded) ?? false
        let hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        let inputPreference = try container.decodeIfPresent(InputPreference.self, forKey: .inputPreference) ?? .pencilOnly
        let strokeSize = try container.decodeIfPresent(StrokeSizePreference.self, forKey: .strokeSize) ?? .standard
        let difficulty = try container.decodeIfPresent(PracticeDifficulty.self, forKey: .difficulty) ?? .intermediate
        let prefersGuides = try container.decodeIfPresent(Bool.self, forKey: .prefersGuides) ?? true
        self.init(isLeftHanded: isLeftHanded,
                  hapticsEnabled: hapticsEnabled,
                  inputPreference: inputPreference,
                  strokeSize: strokeSize,
                  difficulty: difficulty,
                  prefersGuides: prefersGuides)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isLeftHanded, forKey: .isLeftHanded)
        try container.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try container.encode(inputPreference, forKey: .inputPreference)
        try container.encode(strokeSize, forKey: .strokeSize)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(prefersGuides, forKey: .prefersGuides)
    }

    static let `default` = UserSettings(isLeftHanded: false,
                                        hapticsEnabled: true,
                                        inputPreference: .pencilOnly,
                                        strokeSize: .standard,
                                        difficulty: .intermediate,
                                        prefersGuides: true)
}
