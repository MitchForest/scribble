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
    @Published private(set) var contentVersion: String

    private let persistenceURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let assetsVersion: String

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
                                            contentVersion: contentVersion)
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            print("⚠️ Failed to save practice data: \(error)")
        }
    }

    private func seedDefaults() {
        attemptsByLetter = [:]
        masteryByLetter = [:]
        for (index, letterId) in Self.focusLetters.enumerated() {
            masteryByLetter[letterId] = defaultMasteryRecord(for: letterId, unlocked: index == 0)
        }
        settings = .default
        contentVersion = assetsVersion
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
}
