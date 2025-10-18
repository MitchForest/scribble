import XCTest
import PencilKit
@testable import scribble

final class CheckpointValidatorTests: XCTestCase {
    private let rowHeight: CGFloat = 120
    private let startDotRadius: CGFloat = 12
    private let userInkWidth: CGFloat = 6
    private lazy var profile = PracticeDifficulty.beginner.profile

    func testCheckpointsCompleteInOrder() throws {
        let template = try loadTemplate(named: "l.lower", rowHeight: rowHeight)
        let configuration = profile.validationConfiguration(rowHeight: rowHeight,
                                                             visualStartRadius: startDotRadius,
                                                             userInkWidth: userInkWidth)
        let drawing = makeDrawing(from: [template.strokes[0].points])

        let result = CheckpointValidator.evaluate(drawing: drawing,
                                                  template: template,
                                                  configuration: configuration)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.completedCheckpointCount, result.totalCheckpointCount)
        XCTAssertTrue(result.isComplete)
    }

    func testMissedStartFailsOutOfOrder() throws {
        let template = try loadTemplate(named: "m.lower", rowHeight: rowHeight)
        let configuration = profile.validationConfiguration(rowHeight: rowHeight,
                                                             visualStartRadius: startDotRadius,
                                                             userInkWidth: userInkWidth)
        // Skip the first path and attempt to start on the second path.
        let drawing = makeDrawing(from: [template.strokes[1].points])

        let result = CheckpointValidator.evaluate(drawing: drawing,
                                                  template: template,
                                                  configuration: configuration)
        if let failure = result.failure {
            XCTAssertEqual(failure, .outOfOrder)
        } else {
            XCTAssertFalse(result.isComplete)
            XCTAssertLessThan(result.completedCheckpointCount, result.totalCheckpointCount)
        }
    }

    func testLowercaseALoopCompletesWithContinuousInk() throws {
        let template = try loadTemplate(named: "a.lower", rowHeight: rowHeight)
        let configuration = profile.validationConfiguration(rowHeight: rowHeight,
                                                             visualStartRadius: startDotRadius,
                                                             userInkWidth: userInkWidth)

        let combined = template.strokes.flatMap { $0.points }
        let drawing = makeDrawing(from: [combined])

        let result = CheckpointValidator.evaluate(drawing: drawing,
                                                  template: template,
                                                  configuration: configuration)

        XCTAssertNil(result.failure)
        XCTAssertEqual(result.completedCheckpointCount, result.totalCheckpointCount)
        XCTAssertTrue(result.isComplete)
    }

    func testSkippingForwardTriggersOutOfOrder() throws {
        let template = try loadTemplate(named: "l.lower", rowHeight: rowHeight)
        let configuration = profile.validationConfiguration(rowHeight: rowHeight,
                                                             visualStartRadius: startDotRadius,
                                                             userInkWidth: userInkWidth)
        let stroke = template.strokes[0]
        guard stroke.points.count > 8 else {
            XCTFail("Expected sufficient points")
            return
        }

        let firstSegment = Array(stroke.points.prefix(4))
        let skipForward = Array(stroke.points.suffix(4))
        let drawing = makeDrawing(from: [firstSegment + skipForward])

        let result = CheckpointValidator.evaluate(drawing: drawing,
                                                  template: template,
                                                  configuration: configuration)
        if let failure = result.failure {
            XCTAssertEqual(failure, .outOfOrder)
        } else {
            XCTAssertFalse(result.isComplete)
            XCTAssertLessThan(result.completedCheckpointCount, result.totalCheckpointCount)
        }
    }

    func testPartialStrokeDoesNotCompleteAllCheckpoints() throws {
        let template = try loadTemplate(named: "m.lower", rowHeight: rowHeight)
        let configuration = profile.validationConfiguration(rowHeight: rowHeight,
                                                             visualStartRadius: startDotRadius,
                                                             userInkWidth: userInkWidth)

        let plan = TraceCheckpointPlan.make(template: template,
                                            checkpointLength: configuration.checkpointLength,
                                            spacing: configuration.spacingLength)

        guard let firstPath = plan.paths.first, let firstStroke = template.strokes.first else {
            XCTFail("Expected first stroke")
            return
        }

        let sampleCount = max(3, firstStroke.points.count / 25)
        let partialStroke = Array(firstStroke.points.prefix(sampleCount))
        let drawing = makeDrawing(from: [partialStroke])

        let result = CheckpointValidator.evaluate(drawing: drawing,
                                                  template: template,
                                                  configuration: configuration)

        let completed = Set(result.checkpointStatuses.filter { $0.completed }.map { $0.globalIndex })
        let firstStrokeIndices = Set(firstPath.checkpoints.map { $0.globalIndex })

        XCTAssertFalse(firstStrokeIndices.isSubset(of: completed))
        XCTAssertFalse(result.isComplete)
        XCTAssertLessThan(result.completedCheckpointCount, plan.totalCheckpointCount)
    }

    func testCompletingFirstStrokeDoesNotAdvanceRemainingStrokes() throws {
        let template = try loadTemplate(named: "m.lower", rowHeight: rowHeight)
        let configuration = profile.validationConfiguration(rowHeight: rowHeight,
                                                             visualStartRadius: startDotRadius,
                                                             userInkWidth: userInkWidth)

        let plan = TraceCheckpointPlan.make(template: template,
                                            checkpointLength: configuration.checkpointLength,
                                            spacing: configuration.spacingLength)

        guard let firstPath = plan.paths.first, let firstStroke = template.strokes.first else {
            XCTFail("Expected first stroke")
            return
        }

        let drawing = makeDrawing(from: [firstStroke.points])

        let result = CheckpointValidator.evaluate(drawing: drawing,
                                                  template: template,
                                                  configuration: configuration)

        let completed = Set(result.checkpointStatuses.filter { $0.completed }.map { $0.globalIndex })
        let firstStrokeIndices = Set(firstPath.checkpoints.map { $0.globalIndex })

        XCTAssertTrue(firstStrokeIndices.isSubset(of: completed))
        XCTAssertLessThan(result.completedCheckpointCount, plan.totalCheckpointCount)
        XCTAssertEqual(result.activeCheckpointIndex, firstStrokeIndices.count)
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
                                                azimuth: 0,
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
