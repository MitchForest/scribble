import XCTest
import CoreGraphics
@testable import scribble

final class PracticeTemplateScalingTests: XCTestCase {
    func testScaledTemplateAlignsBaseline() throws {
        let template = stubTemplate()
        let scaled = makeScaledTemplate(template: template)

        XCTAssertEqual(scaled.strokes.count, template.strokes.count)
        XCTAssertGreaterThan(scaled.scaledXHeight, 0)
        XCTAssertLessThanOrEqual(scaled.scaledXHeight, Constants.rowAscender)
    }

    func testLeftHandedMirrorsStartPoint() throws {
        let template = stubTemplate()
        let right = makeScaledTemplate(template: template, isLeftHanded: false)
        let left = makeScaledTemplate(template: template, isLeftHanded: true)

        guard let rightStart = right.strokes.first?.startPoint,
              let leftStart = left.strokes.first?.startPoint else {
            return XCTFail("Missing start point")
        }

        XCTAssertEqual(rightStart.y, leftStart.y, accuracy: 0.001)
        XCTAssertNotEqual(leftStart.x, rightStart.x)
    }

    // MARK: - Helpers

    private func makeScaledTemplate(template: HandwritingTemplate,
                                    isLeftHanded: Bool = false,
                                    width: CGFloat = 600) -> ScaledTemplate {
        ScaledTemplate(
            template: template,
            availableWidth: width,
            rowAscender: Constants.rowAscender,
            rowDescender: Constants.rowDescender,
            isLeftHanded: isLeftHanded
        )
    }

    private func stubTemplate() -> HandwritingTemplate {
        let metrics = HandwritingTemplate.Metrics(
            unitsPerEm: 1978,
            baseline: 0,
            xHeight: 614,
            ascender: 1296,
            descender: -682,
            targetSlantDeg: 12
        )

        let points: [CGPoint] = [
            CGPoint(x: 35, y: 0),
            CGPoint(x: 220, y: 320),
            CGPoint(x: 400, y: 450),
            CGPoint(x: 705, y: 614)
        ]

        return HandwritingTemplate(
            id: "stub",
            metrics: metrics,
            strokePoints: [points]
        )
    }

    private enum Constants {
        static let rowAscender: CGFloat = 120
        static let rowDescender: CGFloat = 60
    }
}
