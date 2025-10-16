import SwiftUI
import PencilKit
import UIKit

struct PracticeSessionView: View {
    let letterId: String
    let template: HandwritingTemplate
    @Binding var stage: PracticeStage
    let allowFingerInput: Bool
    let isLeftHanded: Bool
    let strokeSize: StrokeSizePreference
    let hapticsEnabled: Bool
    let onStageComplete: (StageOutcome) -> Void

    private let canvasPadding: CGFloat = 80

    @State private var scaledTemplate: ScaledTemplate?
    @State private var drawing = PKDrawing()
    @State private var strokeProgress: [CGFloat] = []
    @State private var previousStrokeCount = 0
    @State private var currentDotIndex = 0
    @State private var stageCompleted = false
    @State private var stageFeedback: StageOutcome?
    @State private var animationToken = 0
    @State private var hasUserDrawn = false
    @State private var evaluationWorkItem: DispatchWorkItem?
    @State private var stageStart = Date()

    private var rowMetrics: RowMetrics {
        strokeSize.metrics
    }

    private var rowAscender: CGFloat {
        rowMetrics.ascender
    }

    private var rowDescender: CGFloat {
        rowMetrics.descender
    }

    private var rowHeight: CGFloat {
        rowAscender + rowDescender
    }

    private var canvasHeight: CGFloat {
        rowHeight + canvasPadding
    }

    private var practiceLineWidth: CGFloat {
        switch strokeSize {
        case .large: return 8
        case .standard: return 6
        case .compact: return 5
        }
    }

    private var guideLineWidth: CGFloat {
        switch strokeSize {
        case .large: return 6
        case .standard: return 5
        case .compact: return 4
        }
    }

    private var startDotDiameter: CGFloat {
        switch strokeSize {
        case .large: return 20
        case .standard: return 16
        case .compact: return 14
        }
    }

    private var userInkWidth: CGFloat {
        switch strokeSize {
        case .large: return 7
        case .standard: return 6
        case .compact: return 5
        }
    }

    private var toleranceScale: CGFloat {
        let standardAscender = StrokeSizePreference.standard.metrics.ascender
        guard standardAscender > 0 else { return 1 }
        return rowAscender / standardAscender
    }

    private var startTolerance: CGFloat {
        28 * toleranceScale
    }

    private var deviationTolerance: CGFloat {
        36 * toleranceScale
    }

    var body: some View {
        VStack(spacing: 20) {
        TargetLetterLoopView(template: template,
                             animationToken: animationToken,
                             stage: stage,
                             isLeftHanded: isLeftHanded,
                             shouldAnimate: !hasUserDrawn,
                             lineWidth: practiceLineWidth)
                .frame(height: 150)

            GeometryReader { proxy in
                practiceCanvas(size: proxy.size)
            }
            .frame(height: canvasHeight)

            controlBar

            if let feedback = stageFeedback {
                StageResultBanner(stage: feedback.stage, score: feedback.score)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 24)
        .onAppear { resetCanvas() }
        .onChange(of: stage) { _ in resetCanvas() }
        .onChange(of: strokeSize) { _ in handleStrokeSizeChange() }
        .onDisappear { evaluationWorkItem?.cancel() }
    }

    private func practiceCanvas(size: CGSize) -> some View {
        let width = size.width
        let height = size.height
        let verticalInset = max(0, (height - rowHeight) / 2)
        let scaled = scaledTemplate(for: width)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.96, green: 0.98, blue: 1.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color(red: 0.78, green: 0.86, blue: 1.0).opacity(0.7), lineWidth: 2)
                )
                .frame(width: width, height: height)
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)

            if let scaled {
                PracticeRowGuides(width: width,
                                  ascender: rowAscender,
                                  descender: rowDescender,
                                  scaledXHeight: scaled.scaledXHeight,
                                  guideLineWidth: guideLineWidth)
                .padding(.vertical, verticalInset)

                PracticeOverlayView(stage: stage,
                                     strokes: scaled.strokes,
                                     progress: strokeProgress,
                                     currentDotIndex: currentDotIndex,
                                     practiceLineWidth: practiceLineWidth,
                                     guideLineWidth: guideLineWidth,
                                     startDotSize: startDotDiameter)
                .padding(.vertical, verticalInset)

                PencilCanvasView(drawing: $drawing,
                                 onDrawingChanged: { updated in
                                     processDrawingChange(updated, scaledTemplate: scaled)
                                 },
                                 allowFingerFallback: allowFingerInput,
                                 lineWidth: userInkWidth)
                .padding(.vertical, verticalInset)
                .allowsHitTesting(!stageCompleted)
                .background(Color.clear)

                if let warningMessage = warningMessage {
                    WarningToast(text: warningMessage)
                        .padding(.top, verticalInset + 12)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var controlBar: some View {
        HStack {
            Button {
                clearCurrentDrawing()
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color(red: 0.22, green: 0.34, blue: 0.52))
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.96)))
            }
            .accessibilityLabel("Clear drawing")
            .buttonStyle(.plain)
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)

            Spacer()
        }
        .padding(.horizontal, 8)
    }

    private func scaledTemplate(for width: CGFloat) -> ScaledTemplate? {
        if let cached = scaledTemplate, let lastWidth = scaledTemplate?.width, abs(lastWidth - width) < 1 {
            return cached
        }
        let newScaled = ScaledTemplate(template: template,
                                       availableWidth: width,
                                       rowAscender: rowAscender,
                                       rowDescender: rowDescender,
                                       isLeftHanded: isLeftHanded)
        scaledTemplate = newScaled
        strokeProgress = Array(repeating: 0, count: newScaled.strokes.count)
        startAnimationIfNeeded()
        return newScaled
    }

    @State private var warningMessage: String?

    private func resetCanvas() {
        evaluationWorkItem?.cancel()
        drawing = PKDrawing()
        previousStrokeCount = 0
        currentDotIndex = 0
        stageCompleted = false
        stageFeedback = nil
        warningMessage = nil
        hasUserDrawn = false
        animationToken += 1
        strokeProgress = Array(repeating: 0, count: scaledTemplate?.strokes.count ?? 0)
        stageStart = Date()
        startAnimationIfNeeded()
    }

    private func clearCurrentDrawing() {
        evaluationWorkItem?.cancel()
        drawing = PKDrawing()
        previousStrokeCount = 0
        currentDotIndex = 0
        stageCompleted = false
        stageFeedback = nil
        warningMessage = nil
        hasUserDrawn = false
        animationToken += 1
        strokeProgress = Array(repeating: 0, count: scaledTemplate?.strokes.count ?? 0)
        stageStart = Date()
        startAnimationIfNeeded()
    }

    private func handleStrokeSizeChange() {
        scaledTemplate = nil
        resetCanvas()
    }

    private func startAnimationIfNeeded() {
        guard let scaledTemplate else { return }
        guard stage == .guidedTrace else { return }
        if hasUserDrawn {
            strokeProgress = Array(repeating: 1.0, count: scaledTemplate.strokes.count)
            return
        }
        let token = animationToken
        strokeProgress = Array(repeating: 0, count: scaledTemplate.strokes.count)
        let baseDelay = 0.2
        let duration: Double = 1.0

        for index in scaledTemplate.strokes.indices {
            let delay = baseDelay + Double(index) * (duration + 0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard token == animationToken else { return }
                withAnimation(.linear(duration: duration)) {
                    strokeProgress[index] = 1.0
                }
            }
        }

        let total = baseDelay + Double(scaledTemplate.strokes.count) * (duration + 0.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            guard token == animationToken else { return }
            if !stageCompleted && !hasUserDrawn {
                startAnimationIfNeeded()
            }
        }
    }

    private func scheduleEvaluation(after delay: TimeInterval) {
        evaluationWorkItem?.cancel()
        let workItem = DispatchWorkItem { evaluateStage() }
        evaluationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func evaluateStage() {
        guard !stageCompleted, let scaledTemplate else { return }
        let evaluator = PracticeEvaluator(template: scaledTemplate,
                                          drawing: drawing,
                                          startTolerance: startTolerance,
                                          deviationTolerance: deviationTolerance)
        let result = evaluator.evaluate()
        let tips = generateTips(from: result)
        let outcome = StageOutcome(stage: stage,
                                   score: result,
                                   tips: tips,
                                   duration: Date().timeIntervalSince(stageStart))
        stageCompleted = true
        stageFeedback = outcome
        withAnimation(.easeInOut(duration: 0.25)) {
            warningMessage = nil
        }
        onStageComplete(outcome)
    }

    private func processDrawingChange(_ drawing: PKDrawing, scaledTemplate: ScaledTemplate) {
        guard !stageCompleted else { return }
        let strokes = drawing.strokes
        defer { previousStrokeCount = strokes.count }

        guard !strokes.isEmpty else { return }

        if strokes.count > previousStrokeCount, let newStroke = strokes.last {
            let strokeIndex = min(strokes.count - 1, scaledTemplate.strokes.count - 1)
            let templateStroke = scaledTemplate.strokes[strokeIndex]
            if !checkStartPoint(stroke: newStroke,
                                strokeIndex: strokeIndex,
                                templateStroke: templateStroke) {
                let reverted = StartPointGate.removeLastStroke(from: drawing)
                self.drawing = reverted
                previousStrokeCount = reverted.strokes.count
                return
            }
            animationToken += 1
            hasUserDrawn = true
            if stage == .dotGuided {
                currentDotIndex = min(strokeIndex + 1, scaledTemplate.strokes.count)
            }
        }

        if let latestStroke = strokes.last {
            let strokeIndex = min(strokes.count - 1, scaledTemplate.strokes.count - 1)
            checkDeviation(stroke: latestStroke,
                           strokeIndex: strokeIndex,
                           templateStroke: scaledTemplate.strokes[strokeIndex])
        }

        if stage == .guidedTrace || stage == .dotGuided {
            let expectedCount = scaledTemplate.strokes.count
            if strokes.count >= expectedCount {
                scheduleEvaluation(after: 0.2)
            }
        } else {
            let expectedCount = scaledTemplate.strokes.count
            if strokes.count >= expectedCount {
                scheduleEvaluation(after: 0.8)
            }
        }
    }

    @discardableResult
    private func checkStartPoint(stroke: PKStroke, strokeIndex: Int, templateStroke: ScaledStroke) -> Bool {
        guard let firstPoint = stroke.path.firstLocation else { return false }
        let isValid = StartPointGate.isStartValid(startPoint: firstPoint,
                                                 expectedStart: templateStroke.startPoint,
                                                 tolerance: startTolerance)
        if !isValid {
            triggerWarning(.init(strokeIndex: strokeIndex, kind: .start),
                           message: "Start at the green dot")
        }
        return isValid
    }

    private func checkDeviation(stroke: PKStroke, strokeIndex: Int, templateStroke: ScaledStroke) {
        let userPoints = stroke.sampledPoints(step: 4)
        guard !userPoints.isEmpty else { return }

        var maxDistance: CGFloat = 0
        for point in userPoints {
            var nearest = CGFloat.greatestFiniteMagnitude
            for templatePoint in templateStroke.sampledPoints {
                let distance = hypot(point.x - templatePoint.x, point.y - templatePoint.y)
                nearest = min(nearest, distance)
                if nearest < deviationTolerance / 2 {
                    break
                }
            }
            maxDistance = max(maxDistance, nearest)
        }

        if maxDistance > deviationTolerance {
            triggerWarning(.init(strokeIndex: strokeIndex, kind: .deviation),
                           message: "Stay close to the path")
        }
    }

    private func triggerWarning(_ identifier: WarningIdentifier, message: String) {
        warningMessage = message
        if hapticsEnabled {
            HapticsManager.shared.warning()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if !stageCompleted {
                withAnimation(.easeInOut(duration: 0.2)) {
                    warningMessage = nil
                }
            }
        }
    }

    private func generateTips(from result: ScoreResult) -> [TipMessage] {
        var ids: [String] = []
        if result.start < 80 { ids.append("start-point") }
        if result.order < 80 { ids.append("stroke-order") }
        if result.direction < 80 { ids.append("direction") }
        if result.shape < 80 { ids.append("shape-tighten") }
        return ids.prefix(2).compactMap { id in
            guard let text = TipMessage.catalog[id] else { return nil }
            return TipMessage(id: id, text: text)
        }
    }
}

private struct PracticeOverlayView: View {
    let stage: PracticeStage
    let strokes: [ScaledStroke]
    let progress: [CGFloat]
    let currentDotIndex: Int
    let practiceLineWidth: CGFloat
    let guideLineWidth: CGFloat
    let startDotSize: CGFloat

    var body: some View {
        ZStack {
            baseLetterShape
            stageOverlay
        }
    }

    private var baseLetterShape: some View {
        let baseColor = Color(red: 0.55, green: 0.66, blue: 0.94)
        let opacity: Double
        switch stage {
        case .guidedTrace:
            opacity = 0.35
        case .dotGuided:
            opacity = 0.4
        case .freePractice:
            opacity = 0.3
        }

        return ForEach(Array(strokes.enumerated()), id: \.offset) { _, stroke in
            stroke.path
                .stroke(baseColor.opacity(opacity),
                        style: StrokeStyle(lineWidth: guideLineWidth,
                                           lineCap: .round,
                                           lineJoin: .round))
        }
    }

    @ViewBuilder
    private var stageOverlay: some View {
        switch stage {
        case .guidedTrace:
            ForEach(Array(strokes.enumerated()), id: \.offset) { index, stroke in
                stroke.path
                    .trim(from: 0, to: min(progress[safe: index] ?? 0, 1))
                    .stroke(Color(red: 0.22, green: 0.44, blue: 0.98),
                            style: StrokeStyle(lineWidth: practiceLineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))
                StartDot(position: stroke.startPoint, diameter: startDotSize)
            }
        case .dotGuided:
            ForEach(Array(strokes.enumerated()), id: \.offset) { index, stroke in
                stroke.path
                    .stroke(Color(red: 0.53, green: 0.65, blue: 0.98).opacity(0.5),
                            style: StrokeStyle(lineWidth: guideLineWidth,
                                               lineCap: .round,
                                               lineJoin: .round,
                                               dash: [10, 12]))
                if index == currentDotIndex {
                    StartDot(position: stroke.startPoint, diameter: startDotSize)
                        .scaleEffect(1.15)
                }
            }
        case .freePractice:
            ForEach(Array(strokes.enumerated()), id: \.offset) { _, stroke in
                stroke.path
                    .stroke(Color(red: 0.37, green: 0.55, blue: 0.94).opacity(0.35),
                            style: StrokeStyle(lineWidth: guideLineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))
            }
        }
    }
}

private struct StartDot: View {
    let position: CGPoint
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(Color(red: 0.35, green: 0.8, blue: 0.46))
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .frame(width: diameter, height: diameter)
            .position(position)
    }
}

private struct StageResultBanner: View {
    let stage: PracticeStage
    let score: ScoreResult

    var body: some View {
        VStack(spacing: 8) {
            Text("\(stage.displayName) Score")
                .font(.headline)
            Text("\(score.total)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            HStack(spacing: 16) {
                metricView(label: "Shape", value: score.shape)
                metricView(label: "Order", value: score.order)
                metricView(label: "Direction", value: score.direction)
                metricView(label: "Start", value: score.start)
            }
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    private func metricView(label: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
        }
    }
}

private struct TargetLetterLoopView: View {
    let template: HandwritingTemplate
    let animationToken: Int
    let stage: PracticeStage
    let isLeftHanded: Bool
    let shouldAnimate: Bool
    let lineWidth: CGFloat
    @State private var scaledTemplate: ScaledTemplate?
    @State private var strokeProgress: [CGFloat] = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let scaled = scaledTemplate(for: proxy.size.width) {
                    ForEach(Array(scaled.strokes.enumerated()), id: \.offset) { index, stroke in
                        stroke.path
                            .trim(from: 0, to: min(strokeProgress[safe: index] ?? 0, 1))
                            .stroke(Color.orange.opacity(0.9),
                                    style: StrokeStyle(lineWidth: lineWidth,
                                                       lineCap: .round,
                                                       lineJoin: .round))
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear { startLoop() }
        .onChange(of: animationToken) { _ in startLoop() }
        .onChange(of: stage) { _ in startLoop() }
        .onChange(of: shouldAnimate) { newValue in
            if newValue {
                startLoop()
            } else if let scaledTemplate {
                strokeProgress = Array(repeating: 1.0, count: scaledTemplate.strokes.count)
            }
        }
    }

    private func scaledTemplate(for width: CGFloat) -> ScaledTemplate? {
        if let scaledTemplate, abs(scaledTemplate.width - width) < 1 {
            return scaledTemplate
        }
        let newScaled = ScaledTemplate(template: template,
                                       availableWidth: width,
                                       rowAscender: 120,
                                       rowDescender: 60,
                                       isLeftHanded: isLeftHanded)
        scaledTemplate = newScaled
        strokeProgress = Array(repeating: 0, count: newScaled.strokes.count)
        return newScaled
    }

    private func startLoop() {
        guard let scaledTemplate else { return }
        guard shouldAnimate else {
            strokeProgress = Array(repeating: 1.0, count: scaledTemplate.strokes.count)
            return
        }
        let token = animationToken
        let baseDelay = 0.1
        let duration: Double = 0.9
        strokeProgress = Array(repeating: 0, count: scaledTemplate.strokes.count)
        for index in scaledTemplate.strokes.indices {
            let delay = baseDelay + Double(index) * (duration + 0.15)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard token == animationToken else { return }
                withAnimation(.linear(duration: duration)) {
                    strokeProgress[index] = 1.0
                }
            }
        }
        let total = baseDelay + Double(scaledTemplate.strokes.count) * (duration + 0.15)
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            guard token == animationToken else { return }
             guard shouldAnimate else {
                 strokeProgress = Array(repeating: 1.0, count: scaledTemplate.strokes.count)
                 return
             }
            startLoop()
        }
    }
}

private struct WarningIdentifier: Equatable {
    let strokeIndex: Int
    let kind: WarningKind
}

private enum WarningKind: Equatable {
    case start
    case deviation
}

struct ScaledTemplate: Equatable {
    struct Constants {
        static let horizontalPadding: CGFloat = 32
    }

    let strokes: [ScaledStroke]
    let scaledXHeight: CGFloat
    let letterWidth: CGFloat
    let width: CGFloat

    init(template: HandwritingTemplate,
         availableWidth: CGFloat,
         rowAscender: CGFloat,
         rowDescender: CGFloat,
         isLeftHanded: Bool) {
        let allPoints = template.strokes.flatMap { $0.points }
        let minX = allPoints.map { $0.x }.min() ?? 0
        let maxX = allPoints.map { $0.x }.max() ?? 0

        let scale = rowAscender / CGFloat(template.metrics.ascender)
        let scaledLetterWidth = (CGFloat(maxX - minX) * scale)
        let horizontalSpace = availableWidth - Constants.horizontalPadding
        let offsetX = (horizontalSpace - scaledLetterWidth) / 2 - CGFloat(minX) * scale + Constants.horizontalPadding / 2

        let convertPoint: (CGPoint) -> CGPoint = { point in
            let baseX = CGFloat(point.x - minX) * scale
            let x = isLeftHanded ? (offsetX + (scaledLetterWidth - baseX)) : (offsetX + baseX)
            let y = rowAscender - CGFloat(point.y) * scale
            return CGPoint(x: x, y: y)
        }

        let sortedStrokes = template.strokes.sorted { $0.order < $1.order }
        self.strokes = sortedStrokes.enumerated().map { index, stroke in
            let convertedPoints = stroke.points.map(convertPoint)
            var path = Path()
            if let first = convertedPoints.first {
                path.move(to: first)
                path.addLines(Array(convertedPoints.dropFirst()))
            }
            let startPoint = stroke.start.map(convertPoint) ?? convertedPoints.first ?? .zero
            let endPoint = stroke.end.map(convertPoint) ?? convertedPoints.last ?? .zero
            return ScaledStroke(id: stroke.id,
                                order: stroke.order,
                                path: path,
                                points: convertedPoints,
                                startPoint: startPoint,
                                endPoint: endPoint)
        }

        self.scaledXHeight = CGFloat(template.metrics.xHeight) * scale
        self.letterWidth = scaledLetterWidth
        self.width = availableWidth
    }
}

struct ScaledStroke: Identifiable, Equatable {
    let id: String
    let order: Int
    let path: Path
    let points: [CGPoint]
    let startPoint: CGPoint
    let endPoint: CGPoint

    var directionVector: CGVector? {
        guard let first = points.first, let last = points.last else { return nil }
        return CGVector(dx: last.x - first.x, dy: last.y - first.y)
    }

    var sampledPoints: [CGPoint] {
        let step = max(1, points.count / 60)
        var samples = stride(from: 0, to: points.count, by: step).map { points[$0] }
        if let last = points.last, samples.last != last {
            samples.append(last)
        }
        return samples
    }
}

struct PracticeEvaluator {
    let template: ScaledTemplate
    let drawing: PKDrawing
    let startTolerance: CGFloat
    let deviationTolerance: CGFloat

    func evaluate() -> ScoreResult {
        guard !drawing.strokes.isEmpty else {
            return ScoreResult(total: 0, shape: 0, order: 0, direction: 0, start: 0)
        }

        let orderScore = scoreOrder()
        let directionScore = scoreDirection()
        let shapeScore = scoreShape()
        let startScore = scoreStart()

        let total = Int(round(0.40 * Double(shapeScore)
                              + 0.25 * Double(orderScore)
                              + 0.20 * Double(directionScore)
                              + 0.15 * Double(startScore)))

        return ScoreResult(total: total,
                           shape: shapeScore,
                           order: orderScore,
                           direction: directionScore,
                           start: startScore)
    }

    private func scoreOrder() -> Int {
        let expectedStrokes = template.strokes
        let actualStrokes = drawing.strokes
        guard !expectedStrokes.isEmpty, !actualStrokes.isEmpty else { return 0 }

        var matched = 0
        for index in 0..<min(expectedStrokes.count, actualStrokes.count) {
            guard let actualStart = actualStrokes[index].path.firstLocation else { continue }
            let expectedStart = expectedStrokes[index].startPoint
            let distance = hypot(actualStart.x - expectedStart.x, actualStart.y - expectedStart.y)
            if distance <= startTolerance {
                matched += 1
            }
        }

        let expectedCount = expectedStrokes.count
        let extraStrokes = max(0, actualStrokes.count - expectedCount)
        let penalties = max(0, expectedCount - matched) + extraStrokes
        let effectiveMatches = max(0, expectedCount - penalties)
        return Int((Double(effectiveMatches) / Double(expectedCount)) * 100)
    }

    private func scoreDirection() -> Int {
        let expectedStrokes = template.strokes
        let actualStrokes = drawing.strokes
        guard !expectedStrokes.isEmpty, !actualStrokes.isEmpty else { return 0 }

        let comparisons = min(expectedStrokes.count, actualStrokes.count)
        var total: Double = 0
        var validComparisons = 0

        for index in 0..<comparisons {
            guard let expectedRaw = expectedStrokes[index].directionVector,
                  let actualRaw = actualStrokes[index].directionVector else { continue }

            let expectedVector = expectedRaw.normalized()
            let actualVector = actualRaw.normalized()
            if expectedVector.isZero || actualVector.isZero { continue }

            let dot = max(-1.0, min(1.0, expectedVector.dot(actualVector)))
            total += (dot + 1) / 2
            validComparisons += 1
        }

        guard validComparisons == expectedStrokes.count else { return 0 }
        return Int((total / Double(validComparisons)) * 100)
    }

    private func scoreShape() -> Int {
        let expectedStrokes = template.strokes
        let actualStrokes = drawing.strokes
        guard !expectedStrokes.isEmpty, !actualStrokes.isEmpty else {
            return 0
        }

        let comparisons = zip(expectedStrokes, actualStrokes)
        var totalDistance: CGFloat = 0
        var samples: Int = 0

        for (expected, actual) in comparisons {
            let userPoints = actual.sampledPoints(step: 6)
            for point in userPoints {
                let nearest = expected.sampledPoints.map {
                    hypot(point.x - $0.x, point.y - $0.y)
                }.min() ?? deviationTolerance * 2
                totalDistance += min(nearest, deviationTolerance * 2)
                samples += 1
            }
        }

        guard samples > 0 else { return 0 }
        let average = totalDistance / CGFloat(samples)
        return max(0, 100 - Int((average / deviationTolerance) * 100))
    }

    private func scoreStart() -> Int {
        guard let expected = template.strokes.first else { return 0 }
        guard let actual = drawing.strokes.first?.path.firstLocation else { return 0 }
        let distance = hypot(actual.x - expected.startPoint.x, actual.y - expected.startPoint.y)
        if distance <= startTolerance { return 100 }
        return max(0, 100 - Int((distance - startTolerance)))
    }
}

private struct WarningToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

final class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)

    func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    func notice() {
        impactGenerator.impactOccurred(intensity: 0.5)
    }
}
