import XCTest
import CoreGraphics
@testable import scribble

final class PracticeSessionControllerTests: XCTestCase {
    func testLetterCompletionCyclesRepetitionsBeforeAdvancingLetter() {
        let lesson = makeLesson()
        let timeline = makeTimeline(characters: ["a", "b"])
        let controller = PracticeSessionController(lesson: lesson,
                                                   settings: makeSettings(),
                                                   timeline: timeline,
                                                   repetitions: 3)

        XCTAssertEqual(controller.state.activeRepetitionIndex, 0)
        XCTAssertEqual(controller.state.activeLetterGlobalIndex, 0)

        controller.handle(.start)
        XCTAssertEqual(controller.state.repetitions[0].rows[0].phase, .previewing)

        controller.handle(.letterCompleted(repetition: 0, letterIndex: 0))
        XCTAssertEqual(controller.state.activeRepetitionIndex, 1)
        XCTAssertEqual(controller.state.activeLetterGlobalIndex, 0)
        XCTAssertTrue(controller.state.repetitions[0].rows[0].didCompleteLetter)

        controller.handle(.letterCompleted(repetition: 1, letterIndex: 0))
        XCTAssertEqual(controller.state.activeRepetitionIndex, 2)
        XCTAssertEqual(controller.state.activeLetterGlobalIndex, 0)
        XCTAssertTrue(controller.state.repetitions[1].rows[0].didCompleteLetter)

        controller.handle(.letterCompleted(repetition: 2, letterIndex: 0))
        XCTAssertEqual(controller.state.activeRepetitionIndex, 0)
        XCTAssertEqual(controller.state.activeLetterGlobalIndex, 1)
        XCTAssertTrue(controller.state.repetitions[2].rows[0].didCompleteLetter)
    }

    func testClearAndUpdateTimelineResetState() {
        let lesson = makeLesson()
        let timeline = makeTimeline(characters: ["a"])
        let controller = PracticeSessionController(lesson: lesson,
                                                   settings: makeSettings(),
                                                   timeline: timeline,
                                                   repetitions: 3)
        controller.handle(.start)
        controller.handle(.letterCompleted(repetition: 0, letterIndex: 0))

        controller.handle(.clearAll)
        XCTAssertEqual(controller.state.activeRepetitionIndex, 0)
        XCTAssertEqual(controller.state.activeLetterGlobalIndex, 0)
        XCTAssertFalse(controller.state.repetitions[0].rows[0].didCompleteLetter)

        let updatedTimeline = makeTimeline(characters: ["c", "d"])
        controller.handle(.updateTimeline(updatedTimeline))
        XCTAssertEqual(controller.state.timeline.items.count, 2)
        XCTAssertEqual(controller.state.totalLetters, 2)
        XCTAssertEqual(controller.state.activeLetterGlobalIndex, 0)
        XCTAssertFalse(controller.state.repetitions[0].rows.isEmpty)
    }

    // MARK: - Helpers

    private func makeLesson() -> PracticeLesson {
        PracticeLesson(id: "test.lesson",
                       unitId: .letters,
                       kind: .letter(character: "a", style: .lower),
                       title: "Test",
                       subtitle: "",
                       cardGlyph: "a",
                       practiceText: "ab",
                       referenceText: "ab",
                       order: 1)
    }

    private func makeSettings() -> UserSettings {
        UserSettings(isLeftHanded: false,
                     hapticsEnabled: false,
                     inputPreference: .pencilOnly,
                     strokeSize: .standard,
                     difficulty: .beginner,
                     prefersGuides: true)
    }

    private func makeTimeline(characters: [Character]) -> PracticeTimeline {
        let metrics = HandwritingTemplate.Metrics(unitsPerEm: 100,
                                                  baseline: 0,
                                                  xHeight: 50,
                                                  ascender: 60,
                                                  descender: -40,
                                                  targetSlantDeg: nil)
        let stroke = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)]

        let items: [LetterTimelineItem] = characters.enumerated().map { index, character in
            let template = HandwritingTemplate(id: "test.\\(index)",
                                               script: "test",
                                               variant: "unit",
                                               metrics: metrics,
                                               strokePoints: [stroke])
            return LetterTimelineItem(character: character,
                                      letterId: "test.\\(index)",
                                      template: template,
                                      support: .supported)
        }
        let practiseable = Array(items.indices)
        return PracticeTimeline(items: items, practiseableIndices: practiseable)
    }
}
