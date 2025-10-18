import XCTest
import PencilKit
@testable import scribble

@MainActor
final class PracticeRowViewModelTests: XCTestCase {
    func testResetToPreviewingClearsTransientState() {
        let context = makeContext()
        let viewModel = makeViewModel()

        viewModel.updateEnvironment(context.environment)
        viewModel.reset(to: .previewing, clearDrawing: true)

        XCTAssertEqual(viewModel.state.phase, .previewing)
        XCTAssertEqual(viewModel.state.drawing.strokes.count, 0)
        XCTAssertEqual(viewModel.state.frozenDrawing.strokes.count, 0)
        XCTAssertTrue(viewModel.state.previewStrokeProgress.isEmpty)
        XCTAssertNil(viewModel.state.warningMessage)
    }

    func testStartPreviewWithoutSegmentSkipsDirectlyToWriting() {
        let context = makeContext(includeSegment: false)
        let viewModel = makeViewModel()

        viewModel.updateEnvironment(context.environment)
        viewModel.reset(to: .previewing, clearDrawing: true)
        viewModel.startPreviewIfNeeded()

        XCTAssertEqual(viewModel.state.phase, .writing)
        XCTAssertTrue(viewModel.state.previewStrokeProgress.isEmpty)
    }

    func testStartPreviewWithSegmentAnimatesAndEntersWriting() {
        let context = makeContext()
        let viewModel = makeViewModel()

        viewModel.updateEnvironment(context.environment)
        viewModel.reset(to: .previewing, clearDrawing: true)
        viewModel.startPreviewIfNeeded()

        let expectation = expectation(description: "Preview animation finishes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if viewModel.state.phase == .writing {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(viewModel.state.phase, .writing)
        XCTAssertTrue(viewModel.state.previewStrokeProgress.isEmpty)
    }

    // MARK: - Helpers

    private func makeViewModel() -> PracticeRowViewModel {
        PracticeRowViewModel(
            repetitionIndex: 0,
            initialLetterIndex: 0,
            onLetterComplete: { },
            onWarning: { },
            onSuccessFeedback: { },
            onRetryFeedback: { },
            haptics: StubHaptics()
        )
    }

    private func makeContext(includeSegment: Bool = true) -> (layout: WordLayout, environment: PracticeRowViewModel.Environment) {
        let metrics = PracticeCanvasMetrics(strokeSize: .standard)
        let layout = makeLayout(metrics: metrics)
        let segment = includeSegment ? layout.segments.first : nil
        let environment = PracticeRowViewModel.Environment(
            segment: segment,
            metrics: metrics,
            difficulty: .beginner,
            hapticsEnabled: false
        )
        return (layout, environment)
    }

    private func makeLayout(metrics: PracticeCanvasMetrics) -> WordLayout {
        let items = [makeTimelineItem()]
        return PracticeCanvasSizing.resolve(
            items: items,
            availableWidth: 420,
            baseMetrics: metrics,
            isLeftHanded: false
        ).layout
    }

    private func makeTimelineItem() -> LetterTimelineItem {
        let metrics = HandwritingTemplate.Metrics(
            unitsPerEm: 100,
            baseline: 0,
            xHeight: 50,
            ascender: 60,
            descender: -40,
            targetSlantDeg: nil
        )
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 20),
            CGPoint(x: 40, y: 0)
        ]
        let template = HandwritingTemplate(
            id: "test.stroke",
            metrics: metrics,
            strokePoints: [points]
        )
        return LetterTimelineItem(
            character: "a",
            letterId: "test.stroke",
            template: template,
            support: .supported
        )
    }

    private final class StubHaptics: HapticsProviding {
        func warning() {}
        func success() {}
        func notice(intensity: CGFloat) {}
    }
}
