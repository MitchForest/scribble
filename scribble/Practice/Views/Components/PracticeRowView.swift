import SwiftUI
import PencilKit

struct PracticeRowView: View {
    @ObservedObject var viewModel: PracticeRowViewModel
    let layout: WordLayout
    let metrics: PracticeCanvasMetrics
    let canvasWidth: CGFloat
    let rowHeight: CGFloat
    let allowFingerInput: Bool
    let guidesEnabled: Bool
    let segment: WordLayout.Segment?

    private var state: PracticeRowViewModel.State { viewModel.state }

    var body: some View {
        let drawingBinding = Binding(
            get: { state.drawing },
            set: { viewModel.setDrawingSnapshot($0) }
        )

        return ZStack(alignment: .topLeading) {
            PracticeRowGuides(width: layout.width,
                              ascender: layout.ascender,
                              descender: layout.descender,
                              scaledXHeight: layout.scaledXHeight,
                              guideLineWidth: metrics.guideLineWidth)
            .padding(.leading, layout.leadingInset)
            .padding(.trailing, layout.trailingInset)
            .allowsHitTesting(false)

            WordGuidesOverlay(layout: layout,
                              metrics: metrics,
                              currentIndex: viewModel.letterIndex,
                              currentStrokeIndex: state.currentStrokeIndex,
                              guidesEnabled: guidesEnabled,
                              analysis: state.lastAnalysis,
                              isActiveRow: state.isWriting)
            .allowsHitTesting(false)

            if state.isPreviewing,
               let previewSegment = segment {
                PreviewStrokeOverlay(segment: previewSegment,
                                     progress: state.previewStrokeProgress,
                                     lineWidth: previewSegment.lineWidth)
                .allowsHitTesting(false)
            }

            StaticDrawingView(drawing: state.frozenDrawing)
                .allowsHitTesting(false)
                .frame(width: canvasWidth, height: rowHeight)

            PencilCanvasView(drawing: drawingBinding,
            onDrawingChanged: { updated in
                viewModel.handleDrawingChange(updated)
            },
            onLiveStrokeSample: { sample in
                viewModel.handleLiveStrokeSample(sample)
            },
            onLiveStrokeDidEnd: {
                viewModel.handleLiveStrokeDidEnd()
            },
            allowFingerFallback: allowFingerInput,
            lineWidth: metrics.practiceLineWidth)
            .allowsHitTesting(state.isWriting)
            .opacity(state.isWriting ? 1 : 0.35)
            .frame(width: canvasWidth, height: rowHeight)

            if let warning = state.warningMessage {
                VStack {
                    Spacer(minLength: 0)
                    Text(warning)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, max(metrics.rowMetrics.ascender * 0.2, 12))
                        .transition(.opacity)
                }
                .frame(width: canvasWidth, height: rowHeight)
            }

        }
        .frame(width: canvasWidth, height: rowHeight, alignment: .topLeading)
    }
}
