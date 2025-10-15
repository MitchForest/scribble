import XCTest
import PencilKit
import UIKit
@testable import scribble

final class PracticeEvaluatorTests: XCTestCase {
    func testOrderScorePenalizesReversedStrokes() {
        let template = twoStrokeTemplate()
        let scaled = makeScaledTemplate(from: template)

        let firstStart = scaled.strokes[0].startPoint
        let secondStart = scaled.strokes[1].startPoint

        let drawing = makeDrawing([
            StrokeSpec(start: secondStart, end: CGPoint(x: secondStart.x + 40, y: secondStart.y)),
            StrokeSpec(start: firstStart, end: CGPoint(x: firstStart.x + 40, y: firstStart.y))
        ])

        let evaluator = PracticeEvaluator(template: scaled,
                                          drawing: drawing,
                                          startTolerance: 15,
                                          deviationTolerance: 40)
        let result = evaluator.evaluate()
        XCTAssertLessThan(result.order, 100, "Reversed strokes should reduce order score")
    }

    func testDirectionScorePenalizesReverseDirection() {
        let template = twoStrokeTemplate()
        let scaled = makeScaledTemplate(from: template)

        let firstStart = scaled.strokes[0].startPoint
        let firstEnd = scaled.strokes[0].endPoint
        let secondStart = scaled.strokes[1].startPoint
        let secondEnd = scaled.strokes[1].endPoint

        let drawing = makeDrawing([
            StrokeSpec(start: firstEnd, end: firstStart),
            StrokeSpec(start: secondStart, end: secondEnd)
        ])

        let evaluator = PracticeEvaluator(template: scaled,
                                          drawing: drawing,
                                          startTolerance: 15,
                                          deviationTolerance: 40)
        let result = evaluator.evaluate()
        XCTAssertLessThan(result.direction, 100, "Reversed direction should reduce direction score")
    }

    // MARK: - Helpers

    private func twoStrokeTemplate() -> HandwritingTemplate {
        let metrics = HandwritingTemplate.Metrics(
            unitsPerEm: 1000,
            baseline: 0,
            xHeight: 500,
            ascender: 1000,
            descender: -500,
            targetSlantDeg: 12
        )

        let strokeOne: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 200, y: 400),
            CGPoint(x: 400, y: 800)
        ]

        let strokeTwo: [CGPoint] = [
            CGPoint(x: 100, y: 200),
            CGPoint(x: 300, y: 500),
            CGPoint(x: 500, y: 900)
        ]

        return HandwritingTemplate(id: "stub", metrics: metrics, strokePoints: [strokeOne, strokeTwo])
    }

    private func makeScaledTemplate(from template: HandwritingTemplate) -> ScaledTemplate {
        ScaledTemplate(template: template,
                       availableWidth: 600,
                       rowAscender: 120,
                       rowDescender: 60,
                       isLeftHanded: false)
    }

    private func makeDrawing(_ specs: [StrokeSpec]) -> PKDrawing {
        let strokes = specs.map(makeStroke)
        return PKDrawing(strokes: strokes)
    }

    private func makeStroke(from spec: StrokeSpec) -> PKStroke {
        let points = [
            PKStrokePoint(location: spec.start,
                          timeOffset: 0,
                          size: CGSize(width: 2, height: 2),
                          opacity: 1,
                          force: 1,
                          azimuth: 0,
                          altitude: .pi / 4),
            PKStrokePoint(location: spec.end,
                          timeOffset: 0.1,
                          size: CGSize(width: 2, height: 2),
                          opacity: 1,
                          force: 1,
                          azimuth: 0,
                          altitude: .pi / 4)
        ]
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: PKInk(.pen, color: .black), path: path, transform: .identity, mask: nil)
    }

    private struct StrokeSpec {
        let start: CGPoint
        let end: CGPoint
    }
}
