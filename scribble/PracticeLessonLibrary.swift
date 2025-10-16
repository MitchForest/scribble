import Foundation

struct PracticeUnit: Identifiable, Hashable {
    enum ID: String, CaseIterable, Hashable {
        case letters
        case alphabet
        case sentences
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
        case sentence(index: Int)
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

        let sentences = makeSentenceLessons()

        return [
            PracticeUnit(id: .letters,
                         title: "Letters",
                         description: "Master each letter through focused repetition.",
                         lessons: letters),
            PracticeUnit(id: .alphabet,
                         title: "Alphabet",
                         description: "Practice smooth runs of six letters in sequence.",
                         lessons: alphabet),
            PracticeUnit(id: .sentences,
                         title: "Sentences",
                         description: "Keep your flow with single-line sentence drills.",
                         lessons: sentences)
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
        let letters: [Character] = Array("abcdefghijklmnopqrstuvwx")
        return letters.enumerated().map { offset, character in
            let display = styledString(for: character, style: style)
            let practiceText = repeatedSequence(of: display, count: 8)
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
            let sequence = formatted.joined(separator: " ")
            let practiceText = repeatedSequence(of: sequence, count: 2, separator: "   ")
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
                referenceText: sequence,
                order: startingIndex + offset
            )
        }
    }

    private static func makeSentenceLessons() -> [PracticeLesson] {
        let sentences: [String] = [
            "Write with calm focus",
            "Keep the pencil gliding",
            "Light pressure keeps lines clean",
            "Trace the curve with patience",
            "Follow the guide to improve",
            "Steady strokes build rhythm",
            "Pause and breathe between letters",
            "Aim for smooth and even spacing",
            "Let the wrist lead each loop",
            "Relax the grip to stay loose",
            "Anchor your elbow for control",
            "Glide across the page softly",
            "Match the height of every stem",
            "Listen to the rhythm you create",
            "Lean into the forward slant",
            "Round each bowl confidently",
            "Imagine the ink before it appears",
            "Keep your baseline consistent",
            "Stretch tall letters with ease",
            "Leave room for the next word",
            "Finish each tail with grace",
            "Let the stroke land gently",
            "Celebrate small wins today",
            "Practice turns progress into joy",
            "Trust the guide dots to help",
            "Take time to reset your hand",
            "Stay curious with every mark",
            "Smile as the letters flow",
            "Invite play into the practice",
            "Close the session with gratitude"
        ]

        return sentences.enumerated().map { index, sentence in
            PracticeLesson(
                id: "sentences.\(index + 1)",
                unitId: .sentences,
                kind: .sentence(index: index + 1),
                title: "Sentence \(index + 1)",
                subtitle: "Single line",
                cardGlyph: sentence,
                practiceText: sentence,
                referenceText: sentence,
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
}
