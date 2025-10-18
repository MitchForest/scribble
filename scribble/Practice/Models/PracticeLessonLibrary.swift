import Foundation

struct PracticeUnit: Identifiable, Hashable {
    enum ID: String, CaseIterable, Hashable {
        case letters
        case alphabet
        case words
    }

    let id: ID
    let title: String
    let description: String
    let lessons: [PracticeLesson]
}

struct PracticeLesson: Identifiable, Hashable {
    enum CharacterStyle: String, Hashable {
        case lower
        case upper
    }

    enum Kind: Hashable {
        case letter(character: Character, style: CharacterStyle)
        case alphabet(range: ClosedRange<Character>, style: CharacterStyle)
        case word(index: Int)
    }

    typealias ID = String

    let id: ID
    let unitId: PracticeUnit.ID
    let kind: Kind
    let title: String
    let subtitle: String
    let cardGlyph: String
    let practiceText: String
    let referenceText: String
    let order: Int

    var totalLetters: Int {
        practiceText.reduce(into: 0) { count, character in
            if character.isLetter {
                count += 1
            }
        }
    }
}

enum PracticeLessonLibrary {
    static let units: [PracticeUnit] = {
        let lettersLower = makeLetterLessons(style: .lower)
        let lettersUpper = makeLetterLessons(style: .upper, startingIndex: lettersLower.count + 1)
        let letters = lettersLower + lettersUpper

        let alphabetLower = makeAlphabetLessons(style: .lower)
        let alphabetUpper = makeAlphabetLessons(style: .upper, startingIndex: alphabetLower.count + 1)
        let alphabet = alphabetLower + alphabetUpper

        let words = makeWordLessons()

        return [
            PracticeUnit(id: .letters,
                         title: "Letters",
                         description: "Master each letter through focused repetition.",
                         lessons: letters),
            PracticeUnit(id: .alphabet,
                         title: "Alphabet",
                         description: "Practice smooth runs of six letters in sequence.",
                         lessons: alphabet),
            PracticeUnit(id: .words,
                         title: "Words",
                         description: "Build rhythm with short word group drills.",
                         lessons: words)
        ]
    }()

    private static let lessonsByID: [PracticeLesson.ID: PracticeLesson] = {
        Dictionary(uniqueKeysWithValues: units.flatMap { unit in
            unit.lessons.map { ($0.id, $0) }
        })
    }()

    static func lesson(for id: PracticeLesson.ID) -> PracticeLesson? {
        lessonsByID[id]
    }

    static func unit(for id: PracticeUnit.ID) -> PracticeUnit? {
        units.first { $0.id == id }
    }

    // MARK: - Builders

    private static func makeLetterLessons(style: PracticeLesson.CharacterStyle,
                                          startingIndex: Int = 1) -> [PracticeLesson] {
        let letters: [Character] = Array("abcdefghijklmnopqrstuvwxyz")
        return letters.enumerated().map { offset, character in
            let display = styledString(for: character, style: style)
            let practiceText = makeRepeatedPracticeLine(for: character,
                                                        styled: display,
                                                        style: style)
            let subtitle = style == .lower ? "Lowercase drill" : "Uppercase drill"
            let lessonIndex = startingIndex + offset
            let title = "Lesson \(lessonIndex)"
            return PracticeLesson(
                id: "letters.\(style.rawValue).\(display.lowercased())",
                unitId: .letters,
                kind: .letter(character: character, style: style),
                title: title,
                subtitle: subtitle,
                cardGlyph: display,
                practiceText: practiceText,
                referenceText: practiceText,
                order: lessonIndex
            )
        }
    }

    private static func makeAlphabetLessons(style: PracticeLesson.CharacterStyle,
                                            startingIndex: Int = 1) -> [PracticeLesson] {
        let letters: [Character] = Array("abcdefghijklmnopqrstuvwx")
        let chunks = stride(from: 0, to: letters.count, by: 6).map { index -> [Character] in
            let upperBound = min(index + 6, letters.count)
            return Array(letters[index..<upperBound])
        }

        return chunks.enumerated().map { offset, chunk in
            let formatted = chunk.map { styledString(for: $0, style: style) }
            let baseSequence = formatted.joined(separator: letterSeparator)
            let practiceText = makeSequencePracticeLine(from: baseSequence)
            let first = formatted.first ?? ""
            let last = formatted.last ?? ""
            let subtitle = style == .lower ? "Lowercase run" : "Uppercase run"
            let title = "Set \(startingIndex + offset)"

            let lowerBounds = chunk.first ?? "a"
            let upperBounds = chunk.last ?? "f"

            return PracticeLesson(
                id: "alphabet.\(style.rawValue).\(lowerBounds)-\(upperBounds)",
                unitId: .alphabet,
                kind: .alphabet(range: (lowerBounds...upperBounds), style: style),
                title: title,
                subtitle: subtitle,
                cardGlyph: "\(first)-\(last)",
                practiceText: practiceText,
                referenceText: practiceText,
                order: startingIndex + offset
            )
        }
    }

    private static func makeWordLessons() -> [PracticeLesson] {
        let phrases: [String] = [
            "the big cat sat",
            "soft rain taps",
            "bright sun rays",
            "calm winds blow",
            "small birds sing",
            "kids laugh loud",
            "the red kite",
            "cool lake breeze",
            "light clouds drift",
            "fresh green grass",
            "warm tea time",
            "swift fox runs",
            "blue waves roll",
            "quiet night sky",
            "silver moon glow",
            "tiny seeds sprout",
            "brave hearts grow",
            "happy hands draw",
            "gentle streams flow",
            "soft petals fall",
            "golden light spills",
            "sweet honey drips",
            "clear bells ring",
            "bright stars twirl",
            "crisp leaves spin",
            "steady beats drum",
            "shy deer peek",
            "fresh bread bakes",
            "kind words bloom",
            "calm tides rise"
        ]

        return phrases.enumerated().map { index, phrase in
            PracticeLesson(
                id: "words.\(index + 1)",
                unitId: .words,
                kind: .word(index: index + 1),
                title: "Phrase \(index + 1)",
                subtitle: "Word loop",
                cardGlyph: phrase,
                practiceText: phrase,
                referenceText: phrase,
                order: index + 1
            )
        }
    }

    private static func styledString(for character: Character,
                                     style: PracticeLesson.CharacterStyle) -> String {
        switch style {
        case .lower:
            return String(character).lowercased()
        case .upper:
            return String(character).uppercased()
        }
    }

    private static func repeatedSequence(of text: String,
                                         count: Int,
                                         separator: String = " ") -> String {
        guard count > 1 else { return text }
        return Array(repeating: text, count: count).joined(separator: separator)
    }

    private static let letterSeparator = " "
    private static let letterRepeatCount = 6

    private static func makeRepeatedPracticeLine(for _: Character,
                                                  styled display: String,
                                                  style _: PracticeLesson.CharacterStyle) -> String {
        repeatedSequence(of: display,
                         count: letterRepeatCount,
                         separator: letterSeparator)
    }

    private static func makeSequencePracticeLine(from baseSequence: String) -> String {
        baseSequence
    }
}
