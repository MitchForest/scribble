import XCTest
import PencilKit
@testable import scribble

final class RasterStrokeValidatorTests: XCTestCase {
    private let rowHeight: CGFloat = 120
    private let startDotRadius: CGFloat = 12
    private let userInkWidth: CGFloat = 6
    private lazy var profile = PracticeDifficulty.beginner.profile

    func testStrokePassesWithCoverage() throws {
        let template = try loadTemplate(named: "l.lower", rowHeight: rowHeight)
        let configuration = profile.validationConfiguration(rowHeight: rowHeight,
                                                             visualStartRadius: startDotRadius,
                                                             userInkWidth: userInkWidth)
        let drawing = makeDrawing(from: [template.strokes[0].points])

        let result = RasterStrokeValidator.evaluate(drawing: drawing,
                                                    template: template,
                                                    configuration: configuration)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.completedCount, 1)
        XCTAssertTrue(result.reports[0].completed)
        XCTAssertGreaterThan(result.reports[0].coverage, 0.9)
    }

    func testMissedStartFails() throws {
        let template = try loadTemplate(named: "l.lower", rowHeight: rowHeight)
        let configuration = profile.validationConfiguration(rowHeight: rowHeight,
                                                             visualStartRadius: startDotRadius,
                                                             userInkWidth: userInkWidth)
        // Begin midway along the path so the start dot is never touched.
        let offsetPoints = Array(template.strokes[0].points.dropFirst(10))
        let drawing = makeDrawing(from: [offsetPoints])

        let result = RasterStrokeValidator.evaluate(drawing: drawing,
                                                    template: template,
                                                    configuration: configuration)
        XCTAssertEqual(result.failure, .missedStart)
        XCTAssertFalse(result.reports[0].started)
    }

    func testMissedEndFails() throws {
        let template = try loadTemplate(named: "m.lower", rowHeight: rowHeight)
        let configuration = profile.validationConfiguration(rowHeight: rowHeight,
                                                             visualStartRadius: startDotRadius,
                                                             userInkWidth: userInkWidth)
        let firstStroke = template.strokes[0]
        let partial = Array(firstStroke.points.prefix(firstStroke.points.count / 2))
        let secondStart = template.strokes[1].points.prefix(2)
        let drawing = makeDrawing(from: [partial, Array(secondStart)])

        let result = RasterStrokeValidator.evaluate(drawing: drawing,
                                                    template: template,
                                                    configuration: configuration)
        XCTAssertEqual(result.failure, .missedEnd)
        XCTAssertTrue(result.reports[0].started)
        XCTAssertFalse(result.reports[0].reachedEnd)
    }

    func testInsufficientCoverageFails() throws {
        let template = try loadTemplate(named: "l.lower", rowHeight: rowHeight)
        let configuration = profile.validationConfiguration(rowHeight: rowHeight,
                                                             visualStartRadius: startDotRadius,
                                                             userInkWidth: userInkWidth)
        let noisy = template.strokes[0].points.enumerated().map { offsetIndex, point -> CGPoint in
            guard offsetIndex != 0 && offsetIndex != template.strokes[0].points.count - 1 else {
                return point
            }
            let offset: CGFloat = (offsetIndex % 2 == 0) ? configuration.tubeLineWidth * 0.8 : -configuration.tubeLineWidth * 0.8
            return CGPoint(x: point.x, y: point.y + offset)
        }
        let drawing = makeDrawing(from: [noisy])

        let result = RasterStrokeValidator.evaluate(drawing: drawing,
                                                    template: template,
                                                    configuration: configuration)
        XCTAssertEqual(result.failure, .insufficientCoverage)
    }

    // MARK: - Helpers

    private func loadTemplate(named filename: String,
                              rowHeight: CGFloat) throws -> StrokeTraceTemplate {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectURL = testFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let templateURL = projectURL
            .appendingPathComponent("scribble/AppAssets/HandwritingTemplates/templates/alpha-lower/\(filename).json")

        let handwriting = try HandwritingTemplateLoader.decodeTemplate(from: templateURL)
        let scale = rowHeight / max(CGFloat(handwriting.metrics.ascender), 1)
        let minX = handwriting.strokes.flatMap { $0.points }.map { CGFloat($0.x) }.min() ?? 0
        let minY = handwriting.strokes.flatMap { $0.points }.map { CGFloat($0.y) }.min() ?? 0

        let strokes = handwriting.strokes
            .sorted { $0.order < $1.order }
            .map { stroke -> StrokeTraceTemplate.Stroke in
                let scaledPoints = stroke.points.map { point in
                    CGPoint(x: (CGFloat(point.x) - minX) * scale,
                            y: (CGFloat(point.y) - minY) * scale)
                }
                let startPoint = stroke.start.map { CGPoint(x: (CGFloat($0.x) - minX) * scale,
                                                            y: (CGFloat($0.y) - minY) * scale) } ?? scaledPoints.first ?? .zero
                let endPoint = stroke.end.map { CGPoint(x: (CGFloat($0.x) - minX) * scale,
                                                        y: (CGFloat($0.y) - minY) * scale) } ?? scaledPoints.last ?? .zero
                return StrokeTraceTemplate.Stroke(id: stroke.id,
                                                  order: stroke.order,
                                                  points: scaledPoints,
                                                  startPoint: startPoint,
                                                  endPoint: endPoint)
            }
        return StrokeTraceTemplate(strokes: strokes)
    }

    private func makeDrawing(from strokePointSets: [[CGPoint]]) -> PKDrawing {
        var samples: [PKStrokePoint] = []
        var timeOffset: TimeInterval = 0

        for strokePoints in strokePointSets where !strokePoints.isEmpty {
            for point in strokePoints {
                let strokePoint = PKStrokePoint(location: point,
                                                timeOffset: timeOffset,
                                                size: CGSize(width: 1, height: 1),
                                                opacity: 1,
                                                force: 1,
                                                azimuth: CGVector(dx: 1, dy: 0),
                                                altitude: .pi / 2)
                samples.append(strokePoint)
                timeOffset += 0.02
            }
        }

        let path = PKStrokePath(controlPoints: samples,
                                creationDate: Date(timeIntervalSinceReferenceDate: 0))
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: path)
        return PKDrawing(strokes: [stroke])
    }
}
