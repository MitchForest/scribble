import Foundation

@MainActor
final class PracticeDataStore: ObservableObject {
    static let focusLetters: [String] = {
        let alphabet = Array("abcdefghijklmnopqrstuvwx")
        let lowers = alphabet.map { "\($0).lower" }
        let uppers = alphabet.map { "\($0).upper" }
        return lowers + uppers
    }()

    @Published private(set) var attemptsByLetter: [String: [LetterAttemptRecord]] = [:]
    @Published private(set) var masteryByLetter: [String: LetterMasteryRecord] = [:]
    @Published private(set) var settings: UserSettings = .default
    @Published private(set) var latestFlowOutcomes: [String: LetterFlowOutcome] = [:]
    @Published private(set) var contentVersion: String
    @Published private(set) var profile: UserProfile = .default
    @Published private(set) var xpEvents: [XPEvent] = []
    @Published private(set) var lessonProgressRecords: [PracticeLesson.ID: LessonProgressRecord] = [:]

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
        settings.prefersGuides = settings.difficulty.profile.showsGuides
        saveSnapshot()
    }

    func updateInputPreference(_ preference: InputPreference) {
        settings.inputPreference = preference
        saveSnapshot()
    }

    func updateDifficulty(_ difficulty: PracticeDifficulty) {
        settings.difficulty = difficulty
        settings.strokeSize = strokeSize(for: difficulty)
        settings.prefersGuides = difficulty.profile.showsGuides
        saveSnapshot()
    }

    func displayName(for letterId: String) -> String {
        letterId.components(separatedBy: ".").first?.uppercased() ?? letterId
    }

    func lessonProgress(for lesson: PracticeLesson) -> LessonProgress {
        let total = max(lesson.totalLetters, 1)
        let record = lessonProgressRecords[lesson.id]
        let completed = min(record?.completedLetters ?? 0, total)
        return LessonProgress(completed: completed, total: total)
    }

    func updateLessonProgress(for lesson: PracticeLesson,
                              completedLetters: Int,
                              totalLetters: Int,
                              updatedAt: Date = Date()) {
        let clampedTotal = max(totalLetters, 0)
        let clampedCompleted = min(max(completedLetters, 0), clampedTotal)
        var record = lessonProgressRecords[lesson.id] ?? LessonProgressRecord(lessonId: lesson.id,
                                                                              completedLetters: 0,
                                                                              updatedAt: updatedAt)
        guard record.completedLetters != clampedCompleted else {
            return
        }
        record.completedLetters = clampedCompleted
        record.updatedAt = updatedAt
        lessonProgressRecords[lesson.id] = record
        saveSnapshot()
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
            if let storedLessonProgress = snapshot.lessonProgress {
                lessonProgressRecords = Dictionary(uniqueKeysWithValues: storedLessonProgress.map { ($0.lessonId, $0) })
            } else {
                lessonProgressRecords = [:]
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
                                            xpEvents: xpEvents.sorted(by: { $0.createdAt < $1.createdAt }),
                                            lessonProgress: orderedLessonProgress())
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

    private func orderedLessonProgress() -> [LessonProgressRecord] {
        lessonProgressRecords.values.sorted(by: { $0.lessonId < $1.lessonId })
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
        lessonProgressRecords = [:]
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

    func addWritingSeconds(_ seconds: Int,
                           category: XPEvent.Category,
                           letterId: String? = nil,
                           note: String? = nil,
                           at date: Date = Date()) {
        guard seconds > 0 else { return }
        let capped = min(seconds, 9_999)
        let event = XPEvent(amount: capped,
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

    func updateGoalSeconds(_ seconds: Int) {
        var goal = profile.goal
        let minimum = PracticeGoal.secondsPerLetter
        let adjusted = max(minimum, seconds - (seconds % PracticeGoal.secondsPerLetter))
        goal.dailySeconds = adjusted
        updateGoal(goal)
    }

    func updateAvatarSeed(_ seed: String) {
        profile.avatarSeed = seed
        saveSnapshot()
    }

    func updateDisplayName(_ name: String) {
        profile.displayName = name
        saveSnapshot()
    }

    func secondsSpent(on date: Date) -> Int {
        let anchor = startOfDay(for: date)
        return secondsTotalsByDay()[anchor, default: 0]
    }

    func dailyProgressRatio(for date: Date = Date()) -> Double {
        let goal = max(profile.goal.dailySeconds, 1)
        guard goal > 0 else { return 0 }
        return min(Double(secondsSpent(on: date)) / Double(goal), 1)
    }

    func didHitGoal(on date: Date) -> Bool {
        guard profile.goal.dailySeconds > 0 else { return false }
        return secondsSpent(on: date) >= profile.goal.dailySeconds
    }

    func contributions(forDays days: Int = 42, endingAt endDate: Date = Date()) -> [ContributionDay] {
        guard days > 0 else { return [] }
        let goal = profile.goal.dailySeconds
        let secondsByDay = secondsTotalsByDay()
        let endAnchor = startOfDay(for: endDate)
        var contributions: [ContributionDay] = []
        contributions.reserveCapacity(days)

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endAnchor) else { continue }
            let anchor = startOfDay(for: date)
            let earned = secondsByDay[anchor, default: 0]
            contributions.append(ContributionDay(date: anchor,
                                                 secondsSpent: earned,
                                                 goalSeconds: goal))
        }
        return contributions
    }

    func todayContribution() -> ContributionDay {
        let today = startOfDay(for: Date())
        return ContributionDay(date: today,
                               secondsSpent: secondsSpent(on: today),
                               goalSeconds: profile.goal.dailySeconds)
    }

    func weeklyGoalSummary(endingAt date: Date = Date()) -> (hits: Int, target: Int) {
        let recent = contributions(forDays: 7, endingAt: date)
        let goalWeekdays = profile.goal.activeWeekdayIndices
        let hits = recent.filter { day in
            let weekday = weekdayIndex(for: day.date)
            return goalWeekdays.contains(weekday) && day.didHitGoal
        }.count
        return (hits, goalWeekdays.count)
    }

    func currentStreak(asOf date: Date = Date(), lookbackDays: Int = 180) -> Int {
        let goal = profile.goal
        let goalWeekdays = goal.activeWeekdayIndices
        guard goal.dailySeconds > 0, !goalWeekdays.isEmpty else {
            return 0
        }

        let secondsByDay = secondsTotalsByDay()
        var streak = 0
        var checked = 0
        var cursor = startOfDay(for: date)

        while checked < lookbackDays {
            let weekday = weekdayIndex(for: cursor)
            if goalWeekdays.contains(weekday) {
                let total = secondsByDay[cursor, default: 0]
                if total >= goal.dailySeconds {
                    streak += 1
                } else {
                    break
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
            checked += 1
        }

        return streak
    }

    private func secondsTotalsByDay() -> [Date: Int] {
        xpEvents.reduce(into: [:]) { partialResult, event in
            let day = startOfDay(for: event.createdAt)
            partialResult[day, default: 0] += event.amount
        }
    }

    private func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func weekdayIndex(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7
    }

    private func strokeSize(for difficulty: PracticeDifficulty) -> StrokeSizePreference {
        difficulty.profile.strokeSize
    }

private func difficulty(for strokeSize: StrokeSizePreference) -> PracticeDifficulty {
        PracticeDifficulty.allCases.first(where: { $0.profile.strokeSize == strokeSize }) ?? .intermediate
    }
}

extension PracticeDataStore {
    struct LessonProgress: Equatable {
        let completed: Int
        let total: Int
    }
}
