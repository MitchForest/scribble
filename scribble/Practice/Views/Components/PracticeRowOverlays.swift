import SwiftUI
import PencilKit

struct LetterCelebrationOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.08)
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(Color(red: 0.36, green: 0.66, blue: 0.46))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
                Text("Letter Complete")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35), in: Capsule())
            }
        }
    }
}

struct PreviewStrokeOverlay: View {
    let segment: WordLayout.Segment
    let progress: [CGFloat]
    let lineWidth: CGFloat

    private let previewColor = Color(red: 0.32, green: 0.52, blue: 0.98)

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(segment.strokes.enumerated()), id: \.element.id) { index, stroke in
                let amount = index < progress.count ? progress[index] : 0
                stroke.path
                    .trim(from: 0, to: amount)
                    .stroke(previewColor,
                            style: StrokeStyle(lineWidth: lineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))
            }
        }
        .drawingGroup()
    }
}

struct WordGuidesOverlay: View {
    let layout: WordLayout
    let metrics: PracticeCanvasMetrics
    let currentIndex: Int
    let currentStrokeIndex: Int
    let guidesEnabled: Bool
    let analysis: CheckpointValidator.Result?
    let isActiveRow: Bool

    private let completedColor = Color(red: 0.35, green: 0.62, blue: 0.48)
    private let activeColor = Color(red: 0.21, green: 0.41, blue: 0.88)
    private let gradientColor = Color(red: 0.29, green: 0.49, blue: 0.86)
    private let dormantColor = Color(red: 0.72, green: 0.82, blue: 0.94)
    private let cautionColor = Color(red: 0.93, green: 0.43, blue: 0.39)

    private let guidanceDepth = 10

    #if DEBUG
    private static let showCorridorDebug = false
    #else
    private static let showCorridorDebug = false
    #endif

    private var completedCheckpointSet: Set<Int> {
        guard let analysis else { return [] }
        return Set(analysis.checkpointStatuses.filter { $0.completed }.map { $0.globalIndex })
    }

    private var activeCheckpointIndex: Int? {
        guard let analysis, analysis.totalCheckpointCount > 0 else { return nil }
        let clamped = min(max(analysis.activeCheckpointIndex, 0), analysis.totalCheckpointCount - 1)
        return clamped
    }

    @ViewBuilder
    var body: some View {
        if guidesEnabled {
            ZStack(alignment: .topLeading) {
                ForEach(Array(layout.segments.enumerated()), id: \.1.id) { index, segment in
                    if !segment.strokes.isEmpty {
                        drawSegment(segment,
                                    at: index,
                                    isCurrent: index == currentIndex,
                                    isCompleted: index < currentIndex)
                    }
                }
            }
        } else {
            EmptyView()
        }
    }

    private func drawSegment(_ segment: WordLayout.Segment,
                             at index: Int,
                             isCurrent: Bool,
                             isCompleted: Bool) -> some View {
        let activeStroke = isActiveRow && isCurrent && currentStrokeIndex < segment.strokes.count ? currentStrokeIndex : nil

        return ForEach(segment.strokes.indices, id: \.self) { strokeIndex in
            let stroke = segment.strokes[strokeIndex]
            ZStack(alignment: .topLeading) {
                if isCompleted {
                    let color = isActiveRow ? completedColor : completedColor.opacity(0.25)
                    stroke.path
                        .stroke(color,
                                style: StrokeStyle(lineWidth: metrics.guideLineWidth * 0.9,
                                                   lineCap: .round,
                                                   lineJoin: .round))
                } else {
                    let highlightCurrent = isActiveRow && isCurrent
                    let baseDash: [CGFloat] = highlightCurrent ? [] : [6, 8]
                    let baseOpacity = highlightCurrent ? 0.18 : (isActiveRow ? 0.18 : 0.1)
                    let lineWidth = metrics.guideLineWidth * (isActiveRow ? 1 : 0.85)
                    stroke.path
                        .stroke(dormantColor.opacity(baseOpacity),
                                style: StrokeStyle(lineWidth: lineWidth,
                                                   lineCap: .round,
                                                   lineJoin: .round,
                                                   dash: baseDash))

                    if highlightCurrent && strokeIndex == activeStroke {
                        ForEach(stroke.checkpointSegments, id: \.index) { checkpoint in
                            if let color = colorForCheckpoint(checkpoint.index) {
                                stroke.path
                                    .trimmedPath(from: checkpoint.startProgress, to: checkpoint.endProgress)
                                    .stroke(color,
                                            style: StrokeStyle(lineWidth: metrics.guideLineWidth,
                                                               lineCap: .round,
                                                               lineJoin: .round))
                            }
                        }
                    }
                }

                if Self.showCorridorDebug {
                    stroke.path
                        .stroke(Color(red: 0.23, green: 0.45, blue: 0.9).opacity(0.15),
                                style: StrokeStyle(lineWidth: metrics.practiceLineWidth,
                                                   lineCap: .round,
                                                   lineJoin: .round))
                }
            }
        }
    }

    private func colorForCheckpoint(_ index: Int) -> Color? {
        if completedCheckpointSet.contains(index) {
            return completedColor
        }

        if let analysis {
            if analysis.isComplete {
                return completedColor
            }

            let activeIndex = activeCheckpointIndex ?? 0

            if index == activeIndex {
                return activeColor.opacity(0.95)
            }

            if index < activeIndex {
                return cautionColor.opacity(0.75)
            }

            let offset = index - activeIndex
            if offset <= guidanceDepth {
                let startOpacity: Double = 0.9
                let endOpacity: Double = 0.12
                let fraction = Double(offset) / Double(max(guidanceDepth, 1))
                let opacity = startOpacity + (endOpacity - startOpacity) * fraction
                return gradientColor.opacity(opacity)
            }

            return nil
        } else {
            if index == 0 {
                return activeColor.opacity(0.95)
            }
            if index <= guidanceDepth {
                let fraction = Double(index) / Double(max(guidanceDepth, 1))
                let opacity = 0.9 + (0.12 - 0.9) * fraction
                return gradientColor.opacity(opacity)
            }
            return nil
        }
    }
}

struct StaticDrawingView: UIViewRepresentable {
    var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.isOpaque = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.drawing = drawing
        return view
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }
}

extension PKDrawing {
    func appending(_ other: PKDrawing) -> PKDrawing {
        PKDrawing(strokes: strokes + other.strokes)
    }
}
