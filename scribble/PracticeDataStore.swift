import Foundation

@MainActor
final class PracticeDataStore: ObservableObject {
    static let focusLetters: [String] = [
        "a.lower", "c.lower", "d.lower", "e.lower",
        "i.lower", "l.lower", "t.lower", "u.lower"
    ]

    @Published private(set) var attemptsByLetter: [String: [LetterAttemptRecord]] = [:]
    @Published private(set) var masteryByLetter: [String: LetterMasteryRecord] = [:]
    @Published private(set) var settings: UserSettings = .default
    @Published private(set) var latestFlowOutcomes: [String: LetterFlowOutcome] = [:]
    @Published private(set) var contentVersion: String
    @Published private(set) var profile: UserProfile = .default
    @Published private(set) var xpEvents: [XPEvent] = []

    private let persistenceURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let assetsVersion: String
    private let calendar = Calendar(identifier: .gregorian)

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        assetsVersion = HandwritingAssets.currentVersion()
        contentVersion = assetsVersion

        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = directory.appendingPathComponent("Scribble", isDirectory: true)
        persistenceURL = folder.appendingPathComponent("practice-data.json")

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("⚠️ Failed to create application support directory: \(error)")
        }

        loadSnapshot()
    }

    func mastery(for letterId: String) -> LetterMasteryRecord {
        if let existing = masteryByLetter[letterId] {
            return existing
        }
        let record = defaultMasteryRecord(for: letterId, unlocked: letterId == Self.focusLetters.first)
        masteryByLetter[letterId] = record
        return record
    }

    func attempts(for letterId: String) -> [LetterAttemptRecord] {
        attemptsByLetter[letterId] ?? []
    }

    func isUnlocked(letterId: String) -> Bool {
        mastery(for: letterId).unlocked
    }

    func recordAttempt(letterId: String,
                       mode: PracticeMode,
                       result: ScoreResult,
                       tips: [String],
                       hintUsed: Bool,
                       drawingData: Data?,
                       duration: TimeInterval,
                       startedAt: Date,
                       completedAt: Date) -> UnlockEvent? {
        var attempts = attemptsByLetter[letterId, default: []]
        let attempt = LetterAttemptRecord(
            id: UUID(),
            letterId: letterId,
            mode: mode,
            score: result,
            tips: tips,
            hintUsed: hintUsed,
            rawDrawing: drawingData,
            durationMs: Int(duration * 1000),
            startedAt: startedAt,
            completedAt: completedAt
        )
        attempts.append(attempt)
        attemptsByLetter[letterId] = attempts

        var mastery = mastery(for: letterId)
        mastery.registerAttempt(score: result, mode: mode, date: completedAt)
        masteryByLetter[letterId] = mastery

        var unlockEvent: UnlockEvent?
        if mastery.memoryPassCount >= 2 {
            unlockEvent = unlockNextLetter(after: letterId)
        }

        saveSnapshot()
        return unlockEvent
    }

    func updateHapticsEnabled(_ isEnabled: Bool) {
        settings.hapticsEnabled = isEnabled
        saveSnapshot()
    }

    func updateLeftHanded(_ isLeftHanded: Bool) {
        settings.isLeftHanded = isLeftHanded
        saveSnapshot()
    }

    func updateStrokeSize(_ size: StrokeSizePreference) {
        settings.strokeSize = size
        settings.difficulty = difficulty(for: size)
        saveSnapshot()
    }

    func updateInputPreference(_ preference: InputPreference) {
        settings.inputPreference = preference
        saveSnapshot()
    }

    func updateDifficulty(_ difficulty: PracticeDifficulty) {
        settings.difficulty = difficulty
        settings.strokeSize = strokeSize(for: difficulty)
        saveSnapshot()
    }

    func displayName(for letterId: String) -> String {
        letterId.components(separatedBy: ".").first?.uppercased() ?? letterId
    }

    private func unlockNextLetter(after letterId: String) -> UnlockEvent? {
        guard let index = Self.focusLetters.firstIndex(of: letterId) else {
            return nil
        }
        let nextIndex = index + 1
        guard nextIndex < Self.focusLetters.count else { return nil }
        let nextId = Self.focusLetters[nextIndex]
        var nextRecord = mastery(for: nextId)
        if nextRecord.unlocked {
            return nil
        }
        nextRecord.unlocked = true
        masteryByLetter[nextId] = nextRecord
        return UnlockEvent(newlyUnlockedLetterId: nextId)
    }

    func recordFlowOutcome(letterId: String,
                           aggregatedScore: ScoreResult,
                           stageSummaries: [StageAttemptSummary],
                           completedAt: Date) {
        latestFlowOutcomes[letterId] = LetterFlowOutcome(letterId: letterId,
                                                         aggregatedScore: aggregatedScore,
                                                         stageSummaries: stageSummaries,
                                                         completedAt: completedAt)
        saveSnapshot()
    }

    private func loadSnapshot() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else {
            seedDefaults()
            return
        }
        do {
            let data = try Data(contentsOf: persistenceURL)
            let snapshot = try decoder.decode(PracticeDataSnapshot.self, from: data)
            attemptsByLetter = Dictionary(grouping: snapshot.attempts, by: { $0.letterId })
            masteryByLetter = Dictionary(uniqueKeysWithValues: snapshot.mastery.map { ($0.letterId, $0) })
            settings = snapshot.settings ?? .default
            contentVersion = snapshot.contentVersion ?? assetsVersion
            profile = snapshot.profile ?? .default
            if let storedEvents = snapshot.xpEvents {
                xpEvents = storedEvents.sorted(by: { $0.createdAt < $1.createdAt })
            } else {
                xpEvents = []
            }
            if let outcomes = snapshot.flowOutcomes {
                latestFlowOutcomes = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.letterId, $0) })
            } else {
                latestFlowOutcomes = [:]
            }
            seedMissingDefaults()
            if contentVersion != assetsVersion {
                contentVersion = assetsVersion
                saveSnapshot()
            }
        } catch {
            print("⚠️ Failed to load practice data: \(error)")
            seedDefaults()
        }
    }

    private func saveSnapshot() {
        let attempts = attemptsByLetter.values.flatMap { $0 }
        let mastery = masteryByLetter.values.sorted { lhs, rhs in
            guard let lhsIndex = Self.focusLetters.firstIndex(of: lhs.letterId),
                  let rhsIndex = Self.focusLetters.firstIndex(of: rhs.letterId) else {
                return lhs.letterId < rhs.letterId
            }
            return lhsIndex < rhsIndex
        }
        let snapshot = PracticeDataSnapshot(attempts: attempts,
                                            mastery: mastery,
                                            settings: settings,
                                            contentVersion: contentVersion,
                                            flowOutcomes: orderedFlowOutcomes(),
                                            profile: profile,
                                            xpEvents: xpEvents.sorted(by: { $0.createdAt < $1.createdAt }))
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            print("⚠️ Failed to save practice data: \(error)")
        }
    }

    private func orderedFlowOutcomes() -> [LetterFlowOutcome] {
        let order = Self.focusLetters
        return order.compactMap { latestFlowOutcomes[$0] }
    }

    private func seedDefaults() {
        attemptsByLetter = [:]
        masteryByLetter = [:]
        latestFlowOutcomes = [:]
        for (index, letterId) in Self.focusLetters.enumerated() {
            masteryByLetter[letterId] = defaultMasteryRecord(for: letterId, unlocked: index == 0)
        }
        settings = .default
        contentVersion = assetsVersion
        profile = .default
        xpEvents = []
        saveSnapshot()
    }

    private func seedMissingDefaults() {
        for (index, letterId) in Self.focusLetters.enumerated() {
            if masteryByLetter[letterId] == nil {
                masteryByLetter[letterId] = defaultMasteryRecord(for: letterId, unlocked: index == 0)
            }
        }
    }

    private func defaultMasteryRecord(for letterId: String, unlocked: Bool) -> LetterMasteryRecord {
        LetterMasteryRecord(
            letterId: letterId,
            bestScore: 0,
            bestMode: nil,
            attemptCount: 0,
            lastPracticedAt: nil,
            memoryPassCount: 0,
            unlocked: unlocked
        )
    }

    func awardXP(amount: Int,
                 category: XPEvent.Category,
                 letterId: String? = nil,
                 note: String? = nil,
                 at date: Date = Date()) {
        guard amount > 0 else { return }
        let cappedAmount = min(amount, 9_999)
        let event = XPEvent(amount: cappedAmount,
                            createdAt: date,
                            category: category,
                            letterId: letterId,
                            note: note)
        xpEvents.append(event)
        xpEvents.sort { $0.createdAt < $1.createdAt }
        saveSnapshot()
    }

    func updateGoal(_ goal: PracticeGoal) {
        profile.goal = goal
        saveSnapshot()
    }

    func updateAvatarSeed(_ seed: String) {
        profile.avatarSeed = seed
        saveSnapshot()
    }

    func updateDisplayName(_ name: String) {
        profile.displayName = name
        saveSnapshot()
    }

    func xpEarned(on date: Date) -> Int {
        let anchor = startOfDay(for: date)
        return xpTotalsByDay()[anchor, default: 0]
    }

    func dailyProgressRatio(for date: Date = Date()) -> Double {
        let goal = max(profile.goal.dailyXP, 1)
        guard goal > 0 else { return 0 }
        return min(Double(xpEarned(on: date)) / Double(goal), 1)
    }

    func didHitGoal(on date: Date) -> Bool {
        guard profile.goal.dailyXP > 0 else { return false }
        return xpEarned(on: date) >= profile.goal.dailyXP
    }

    func contributions(forDays days: Int = 42, endingAt endDate: Date = Date()) -> [ContributionDay] {
        guard days > 0 else { return [] }
        let goal = profile.goal.dailyXP
        let xpByDay = xpTotalsByDay()
        let endAnchor = startOfDay(for: endDate)
        var contributions: [ContributionDay] = []
        contributions.reserveCapacity(days)

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endAnchor) else { continue }
            let anchor = startOfDay(for: date)
            let earned = xpByDay[anchor, default: 0]
            contributions.append(ContributionDay(date: anchor,
                                                 xpEarned: earned,
                                                 goalXP: goal))
        }
        return contributions
    }

    func todayContribution() -> ContributionDay {
        let today = startOfDay(for: Date())
        return ContributionDay(date: today,
                               xpEarned: xpEarned(on: today),
                               goalXP: profile.goal.dailyXP)
    }

    func weeklyGoalSummary(endingAt date: Date = Date()) -> (hits: Int, target: Int) {
        let recent = contributions(forDays: 7, endingAt: date)
        let hits = recent.filter { $0.didHitGoal }.count
        return (hits, profile.goal.activeDaysPerWeek)
    }

    private func xpTotalsByDay() -> [Date: Int] {
        xpEvents.reduce(into: [:]) { partialResult, event in
            let day = startOfDay(for: event.createdAt)
            partialResult[day, default: 0] += event.amount
        }
    }

    private func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func strokeSize(for difficulty: PracticeDifficulty) -> StrokeSizePreference {
        switch difficulty {
        case .easy: return .large
        case .medium: return .standard
        case .hard: return .compact
        }
    }

    private func difficulty(for strokeSize: StrokeSizePreference) -> PracticeDifficulty {
        switch strokeSize {
        case .large: return .easy
        case .standard: return .medium
        case .compact: return .hard
        }
    }
}
