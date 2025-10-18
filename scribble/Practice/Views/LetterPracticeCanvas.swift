import SwiftUI

struct LetterPracticeCanvas: View {
    static let repetitionCount = 3

    let layout: WordLayout
    let metrics: PracticeCanvasMetrics
    let rowViewModels: [PracticeRowViewModel]
    let guidesEnabled: Bool
    let allowFingerInput: Bool
    let activeLetterIndex: Int

    var body: some View {
        let canvasWidth = layout.width + layout.leadingInset + layout.trailingInset
        let rowHeight = metrics.canvasHeight
        let baseRowSpan = metrics.rowMetrics.ascender + metrics.rowMetrics.descender
        let rowSpacing = max(baseRowSpan * 0.18, metrics.practiceLineWidth * 2)
        let totalHeight = rowHeight * CGFloat(rowViewModels.count) + rowSpacing * CGFloat(max(rowViewModels.count - 1, 0))
        let segment = layout.segments[safe: activeLetterIndex]

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                .frame(width: canvasWidth, height: totalHeight)

            ForEach(Array(rowViewModels.enumerated()), id: \.1.repetitionIndex) { index, viewModel in
                PracticeRowView(viewModel: viewModel,
                                layout: layout,
                                metrics: metrics,
                                canvasWidth: canvasWidth,
                                rowHeight: rowHeight,
                                allowFingerInput: allowFingerInput,
                                guidesEnabled: guidesEnabled,
                                segment: segment)
                .offset(y: CGFloat(index) * (rowHeight + rowSpacing))
            }
        }
        .frame(width: canvasWidth, height: totalHeight, alignment: .topLeading)
        .padding(.vertical, 6)
    }
}
