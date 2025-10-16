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
    let difficulty: PracticeDifficulty
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
    @State private var magnetizedStrokes: Set<Int> = []
    @State private var magnetizedOffsets: [Int: CGVector] = [:]
    @State private var lastWarningTime: Date?

    private var profile: PracticeDifficultyProfile {
        difficulty.profile
    }

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
        28 * toleranceScale * profile.startToleranceMultiplier
    }

    private var deviationTolerance: CGFloat {
        36 * toleranceScale * profile.deviationToleranceMultiplier
    }

    private var startSnapRadius: CGFloat {
        max(startTolerance * profile.startSnapMultiplier, startTolerance * 0.4)
    }

    private var corridorRadius: CGFloat {
        deviationTolerance * profile.corridorWidthMultiplier
    }

    private var corridorSoftLimit: CGFloat {
        corridorRadius + profile.corridorSoftness
    }

    private var directionSlackDegrees: CGFloat {
        profile.directionSlackDegrees
    }

    private var warningCooldown: TimeInterval {
        profile.warningCooldown
    }

    private var hapticStyle: PracticeDifficultyProfile.HapticStyle {
        profile.hapticStyle
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
        .onChange(of: stage) { resetCanvas() }
        .onChange(of: strokeSize) { handleStrokeSizeChange() }
        .onChange(of: difficulty) { handleDifficultyChange() }
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
                                     magnetizedStrokes: magnetizedStrokes,
                                     showsGuides: profile.showsGuides,
                                     corridorRadius: corridorRadius,
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
                        .position(x: width / 2,
                                  y: verticalInset + rowAscender + startDotDiameter * 0.6)
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
        magnetizedStrokes.removeAll()
        magnetizedOffsets.removeAll()
        lastWarningTime = nil
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
        magnetizedStrokes.removeAll()
        magnetizedOffsets.removeAll()
        lastWarningTime = nil
        startAnimationIfNeeded()
    }

    private func handleStrokeSizeChange() {
        scaledTemplate = nil
        resetCanvas()
    }

    private func handleDifficultyChange() {
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
                                          profile: profile,
                                          startTolerance: startTolerance,
                                          corridorRadius: corridorRadius,
                                          corridorSoftLimit: corridorSoftLimit,
                                          magnetizedOffsets: magnetizedOffsets,
                                          directionSlackDegrees: directionSlackDegrees)
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
            magnetizedOffsets.removeValue(forKey: strokeIndex)
            magnetizedStrokes.remove(strokeIndex)
            if !checkStartPoint(stroke: newStroke,
                                strokeIndex: strokeIndex,
                                templateStroke: templateStroke) {
                let reverted = StartPointGate.removeLastStroke(from: drawing)
                self.drawing = reverted
                previousStrokeCount = reverted.strokes.count
                magnetizedOffsets.removeValue(forKey: strokeIndex)
                magnetizedStrokes.remove(strokeIndex)
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

        let expectedCount = scaledTemplate.strokes.count
        if shouldEvaluateDrawing(strokes: strokes,
                                 template: scaledTemplate,
                                 expectedCount: expectedCount) {
            let delay: TimeInterval = (stage == .guidedTrace || stage == .dotGuided) ? 0.25 : 0.6
            scheduleEvaluation(after: delay)
        }
    }

    @discardableResult
    private func checkStartPoint(stroke: PKStroke, strokeIndex: Int, templateStroke: ScaledStroke) -> Bool {
        guard let firstPoint = stroke.path.firstLocation else { return false }
        let distance = hypot(firstPoint.x - templateStroke.startPoint.x,
                             firstPoint.y - templateStroke.startPoint.y)

        if distance <= startSnapRadius {
            let offset = CGVector(dx: templateStroke.startPoint.x - firstPoint.x,
                                  dy: templateStroke.startPoint.y - firstPoint.y)
            magnetizedOffsets[strokeIndex] = offset
            magnetizedStrokes.insert(strokeIndex)
            return true
        }

        if distance <= startTolerance {
            magnetizedOffsets.removeValue(forKey: strokeIndex)
            return true
        }

        let forgivenessLimit = startTolerance * profile.startForgivenessMultiplier
        if distance <= forgivenessLimit {
            magnetizedOffsets.removeValue(forKey: strokeIndex)
            triggerWarning(.init(strokeIndex: strokeIndex, kind: .start),
                           message: "Start closer to the green dot")
            return true
        }

        magnetizedOffsets.removeValue(forKey: strokeIndex)
        magnetizedStrokes.remove(strokeIndex)
        triggerWarning(.init(strokeIndex: strokeIndex, kind: .start),
                       message: "Start at the green dot")
        return false
    }

    private func adjustedPoints(for strokeIndex: Int, points: [CGPoint]) -> [CGPoint] {
        guard let offset = magnetizedOffsets[strokeIndex], (offset.dx != 0 || offset.dy != 0) else {
            return points
        }
        return points.map { point in
            CGPoint(x: point.x + offset.dx, y: point.y + offset.dy)
        }
    }

    private func nearestDistance(from point: CGPoint, to templateStroke: ScaledStroke) -> CGFloat {
        var nearest = CGFloat.greatestFiniteMagnitude
        for templatePoint in templateStroke.sampledPoints {
            let distance = hypot(point.x - templatePoint.x, point.y - templatePoint.y)
            if distance < nearest {
                nearest = distance
                if nearest < corridorRadius * 0.25 {
                    break
                }
            }
        }
        return nearest
    }

    private func checkDeviation(stroke: PKStroke, strokeIndex: Int, templateStroke: ScaledStroke) {
        let userPoints = adjustedPoints(for: strokeIndex,
                                        points: stroke.sampledPoints(step: 4))
        guard !userPoints.isEmpty else { return }

        var samples: Int = 0
        var outside: Int = 0
        var worstDistance: CGFloat = 0
        for point in userPoints {
            let distance = nearestDistance(from: point, to: templateStroke)
            worstDistance = max(worstDistance, distance)
            if distance > corridorRadius {
                outside += 1
            }
            samples += 1
            if distance > corridorSoftLimit {
                break
            }
        }

        let outsideRatio = samples > 0 ? CGFloat(outside) / CGFloat(samples) : 0
        if worstDistance > corridorSoftLimit || outsideRatio > 0.45 {
            triggerWarning(.init(strokeIndex: strokeIndex, kind: .deviation),
                           message: "Stay inside the blue path")
        }
    }

    private func triggerWarning(_ identifier: WarningIdentifier, message: String) {
        _ = identifier
        let now = Date()
        let shouldThrottle = lastWarningTime.map { now.timeIntervalSince($0) < warningCooldown } ?? false

        warningMessage = message
        if !shouldThrottle {
            lastWarningTime = now
            if hapticsEnabled {
                sendWarningHaptic()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if !stageCompleted {
                withAnimation(.easeInOut(duration: 0.2)) {
                    warningMessage = nil
                }
            }
        }
    }

    private func shouldEvaluateDrawing(strokes: [PKStroke],
                                       template: ScaledTemplate,
                                       expectedCount: Int) -> Bool {
        if strokes.count >= expectedCount {
            return true
        }
        guard profile.mergedStrokeAllowance > 0 else { return false }
        let minimumRequired = max(1, expectedCount - profile.mergedStrokeAllowance)
        guard strokes.count >= minimumRequired else { return false }
        let evaluator = PracticeEvaluator(template: template,
                                          drawing: drawing,
                                          profile: profile,
                                          startTolerance: startTolerance,
                                          corridorRadius: corridorRadius,
                                          corridorSoftLimit: corridorSoftLimit,
                                          magnetizedOffsets: magnetizedOffsets,
                                          directionSlackDegrees: directionSlackDegrees)
        let coverage = evaluator.coverageRatio()
        return coverage >= profile.completionCoverageThreshold
    }

    private func sendWarningHaptic() {
        switch hapticStyle {
        case .none:
            break
        case .soft:
            HapticsManager.shared.notice()
        case .warning:
            HapticsManager.shared.warning()
        }
    }

    private func generateTips(from result: ScoreResult) -> [TipMessage] {
        let thresholds = tipThresholds
        var ids: [String] = []
        if result.start < thresholds.start { ids.append("start-point") }
        if result.order < thresholds.order { ids.append("stroke-order") }
        if result.direction < thresholds.direction { ids.append("direction") }
        if result.shape < thresholds.shape { ids.append("shape-tighten") }
        return ids.prefix(2).compactMap { id in
            guard let text = TipMessage.catalog[id] else { return nil }
            return TipMessage(id: id, text: text)
        }
    }

    private var tipThresholds: (shape: Int, order: Int, direction: Int, start: Int) {
        switch difficulty {
        case .beginner:
            return (shape: 65, order: 60, direction: 60, start: 65)
        case .intermediate:
            return (shape: 75, order: 70, direction: 70, start: 75)
        case .expert:
            return (shape: 85, order: 80, direction: 80, start: 85)
        }
    }
}

private struct PracticeOverlayView: View {
    let stage: PracticeStage
    let strokes: [ScaledStroke]
    let progress: [CGFloat]
    let currentDotIndex: Int
    let magnetizedStrokes: Set<Int>
    let showsGuides: Bool
    let corridorRadius: CGFloat
    let practiceLineWidth: CGFloat
    let guideLineWidth: CGFloat
    let startDotSize: CGFloat

    #if DEBUG
    private static let showCorridorDebug = false
    #else
    private static let showCorridorDebug = false
    #endif

    private var activeStrokeIndex: Int? {
        switch stage {
        case .guidedTrace:
            if let index = progress.enumerated().first(where: { ($0.element) < 0.999 })?.offset {
                return index
            }
            return strokes.isEmpty ? nil : strokes.indices.last
        case .dotGuided:
            return currentDotIndex < strokes.count ? currentDotIndex : nil
        case .freePractice:
            return nil
        }
    }

    var body: some View {
        ZStack {
            baseLetterShape
            stageOverlay
        }
    }

    @ViewBuilder
    private var baseLetterShape: some View {
        if showsGuides && Self.showCorridorDebug {
            let inactiveColor = Color(red: 0.43, green: 0.59, blue: 0.91).opacity(0.18)
            let inactiveWidth = max(guideLineWidth * 0.6, 1.0)

            ForEach(Array(strokes.enumerated()), id: \.offset) { index, stroke in
                let isActive = index == activeStrokeIndex
                stroke.path
                    .stroke(isActive ? Color.clear : inactiveColor,
                            style: StrokeStyle(lineWidth: inactiveWidth,
                                               lineCap: .round,
                                               lineJoin: .round,
                                               dash: stage == .dotGuided ? [6, 8] : []))
            }
        }
    }

    @ViewBuilder
    private var stageOverlay: some View {
        switch stage {
        case .guidedTrace:
            ForEach(Array(strokes.enumerated()), id: \.offset) { index, stroke in
                let isActive = index == activeStrokeIndex
                let progressValue = min(progress[safe: index] ?? 0, 1)
                let outline: (Color, CGFloat) = {
                    if showsGuides {
                        let color = isActive ? Color(red: 0.19, green: 0.39, blue: 0.92) : Color(red: 0.19, green: 0.39, blue: 0.92).opacity(0.25)
                        let width = isActive ? practiceLineWidth : guideLineWidth * 0.7
                        return (color, width)
                    } else {
                        let color = Color(red: 0.19, green: 0.39, blue: 0.92).opacity(isActive ? 0.55 : 0.12)
                        let width = practiceLineWidth * (isActive ? 0.85 : 0.5)
                        return (color, width)
                    }
                }()
                let outlineColor = outline.0
                let outlineWidth = outline.1

                stroke.path
                    .trim(from: 0, to: progressValue)
                    .stroke(outlineColor,
                            style: StrokeStyle(lineWidth: outlineWidth,
                                               lineCap: .round,
                                               lineJoin: .round))
                if showsGuides {
                    let isMagnetized = magnetizedStrokes.contains(index)
                    StartDot(position: stroke.startPoint,
                             diameter: startDotSize,
                             isHighlighted: isMagnetized)
                }
            }
        case .dotGuided:
            if showsGuides {
                ForEach(Array(strokes.enumerated()), id: \.offset) { index, stroke in
                    let isActive = index == activeStrokeIndex
                    let color = isActive ? Color(red: 0.23, green: 0.45, blue: 0.9) : Color(red: 0.23, green: 0.45, blue: 0.9).opacity(0.28)
                    stroke.path
                        .stroke(color,
                                style: StrokeStyle(lineWidth: guideLineWidth * 0.8,
                                                   lineCap: .round,
                                                   lineJoin: .round,
                                                   dash: [5, 6]))
                    let shouldHighlight = index == currentDotIndex || magnetizedStrokes.contains(index)
                    StartDot(position: stroke.startPoint,
                             diameter: startDotSize,
                             isHighlighted: shouldHighlight)
                }
            }
        case .freePractice:
            if showsGuides {
                ForEach(Array(strokes.enumerated()), id: \.offset) { _, stroke in
                    stroke.path
                        .stroke(Color(red: 0.37, green: 0.55, blue: 0.94).opacity(0.25),
                                style: StrokeStyle(lineWidth: guideLineWidth * 0.75,
                                                   lineCap: .round,
                                                   lineJoin: .round))
                }
            }
        }
    }
}

private struct StartDot: View {
    let position: CGPoint
    let diameter: CGFloat
    let isHighlighted: Bool

    var body: some View {
        Circle()
            .fill(Color(red: 0.35, green: 0.8, blue: 0.46))
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .frame(width: diameter, height: diameter)
            .scaleEffect(isHighlighted ? 1.18 : 1.0)
            .shadow(color: Color(red: 0.35, green: 0.8, blue: 0.46).opacity(isHighlighted ? 0.35 : 0),
                    radius: isHighlighted ? 10 : 0)
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
        .onChange(of: animationToken) { startLoop() }
        .onChange(of: stage) { startLoop() }
        .onChange(of: shouldAnimate) { _, newValue in
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
    let profile: PracticeDifficultyProfile
    let startTolerance: CGFloat
    let corridorRadius: CGFloat
    let corridorSoftLimit: CGFloat
    let magnetizedOffsets: [Int: CGVector]
    let directionSlackDegrees: CGFloat

    func evaluate() -> ScoreResult {
        guard !drawing.strokes.isEmpty else {
            return ScoreResult(total: 0, shape: 0, order: 0, direction: 0, start: 0)
        }

        let shapeScore = scoreShape()
        let orderScore = scoreOrder()
        let directionScore = scoreDirection()
        let startScore = scoreStart()

        let total = Int(round(0.45 * Double(shapeScore)
                              + 0.25 * Double(orderScore)
                              + 0.20 * Double(directionScore)
                              + 0.10 * Double(startScore)))

        return ScoreResult(total: total,
                           shape: shapeScore,
                           order: orderScore,
                           direction: directionScore,
                           start: startScore)
    }

    private func scoreShape() -> Int {
        guard let metrics = computeShapeMetrics() else { return 0 }
        guard metrics.totalSamples > 0 else { return 0 }

        let insideRatio = metrics.inside / metrics.totalSamples
        let outsideRatio = metrics.outside / metrics.totalSamples
        let overflowAverage = metrics.outside > 0 ? metrics.overflow / metrics.outside : 0
        let softBand = max(corridorSoftLimit - corridorRadius, 1)
        let overflowNormalized = min(1, overflowAverage / softBand)

        let tightening = CGFloat(profile.evaluationTighteningRate)
        var final = max(0, min(1, insideRatio - tightening * overflowNormalized - tightening * 0.4 * outsideRatio))

        let completionRatio = min(1, CGFloat(metrics.actualCount) / CGFloat(metrics.expectedCount))
        final *= completionRatio

        if metrics.actualCount > metrics.expectedCount {
            let extra = metrics.actualCount - metrics.expectedCount
            let extraPenalty = tightening * 0.08 * min(1, CGFloat(extra) / CGFloat(metrics.expectedCount + extra))
            final = max(0, final - extraPenalty)
        }

        return Int(round(final * 100))
    }

    func coverageRatio() -> Double {
        guard let metrics = computeShapeMetrics(), metrics.totalSamples > 0 else { return 0 }
        return Double(metrics.inside / metrics.totalSamples)
    }

    private struct ShapeMetrics {
        let inside: CGFloat
        let outside: CGFloat
        let overflow: CGFloat
        let totalSamples: CGFloat
        let expectedCount: Int
        let actualCount: Int
    }

    private func computeShapeMetrics() -> ShapeMetrics? {
        let expected = template.strokes
        let actual = drawing.strokes
        guard !expected.isEmpty, !actual.isEmpty else { return nil }

        let comparisons = min(expected.count, actual.count)
        var inside: CGFloat = 0
        var outside: CGFloat = 0
        var overflow: CGFloat = 0

        for index in 0..<comparisons {
            let expectedStroke = expected[index]
            let points = adjustedPoints(for: actual[index], index: index, step: 4)
            if points.isEmpty { continue }
            for point in points {
                let distance = nearestDistance(from: point, to: expectedStroke)
                if distance <= corridorRadius {
                    inside += 1
                } else {
                    outside += 1
                    overflow += max(0, distance - corridorRadius)
                }
            }
        }

        let totalSamples = inside + outside
        return ShapeMetrics(inside: inside,
                            outside: outside,
                            overflow: overflow,
                            totalSamples: totalSamples,
                            expectedCount: expected.count,
                            actualCount: actual.count)
    }

    private func scoreOrder() -> Int {
        let expected = template.strokes
        let actual = drawing.strokes
        guard !expected.isEmpty, !actual.isEmpty else { return 0 }

        let tolerance = startTolerance * (profile.preservesMistakeStroke ? 1.3 : 1.1)
        var matchedExpected = Set<Int>()
        var assignments: [Int] = []

        for (actualIndex, stroke) in actual.enumerated() {
            guard let start = adjustedStartPoint(for: stroke, index: actualIndex) else { continue }
            var bestIndex: Int?
            var bestDistance = CGFloat.greatestFiniteMagnitude
            for (expectedIndex, expectedStroke) in expected.enumerated() {
                let distance = hypot(start.x - expectedStroke.startPoint.x,
                                     start.y - expectedStroke.startPoint.y)
                if distance < bestDistance {
                    bestDistance = distance
                    bestIndex = expectedIndex
                }
            }

            guard let bestIndex, bestDistance <= tolerance * 1.8 else { continue }
            assignments.append(bestIndex)
            if bestDistance <= tolerance {
                matchedExpected.insert(bestIndex)
            }
        }

        if assignments.isEmpty {
            return 0
        }

        let coverage = Double(matchedExpected.count) / Double(expected.count)
        var orderViolations = 0
        for pair in zip(assignments, assignments.dropFirst()) {
            if pair.1 < pair.0 {
                orderViolations += 1
            }
        }

        let extras = max(0, assignments.count - expected.count)
        let penalizedExtras = max(0, extras - profile.mergedStrokeAllowance)

        let tightening = Double(profile.evaluationTighteningRate)
        let violationPenalty = tightening * Double(orderViolations) / Double(max(expected.count - 1, 1))
        let extraPenalty = tightening * 0.6 * Double(penalizedExtras) / Double(expected.count)

        let score = max(0, min(1, coverage - violationPenalty - extraPenalty))
        return Int(round(score * 100))
    }

    private func scoreDirection() -> Int {
        let expected = template.strokes
        let actual = drawing.strokes
        guard !expected.isEmpty, !actual.isEmpty else { return 0 }

        let comparisons = min(expected.count, actual.count)
        var excessAngles: [Double] = []

        for index in 0..<comparisons {
            let expectedVectors = keyDirectionVectors(for: expected[index])
            let actualVectors = keyDirectionVectors(for: actual[index], index: index)
            guard !expectedVectors.isEmpty, expectedVectors.count == actualVectors.count else { continue }

            for (expectedVector, actualVector) in zip(expectedVectors, actualVectors) {
                let diff = angleDifferenceDegrees(expectedVector, actualVector)
                let slack = Double(directionSlackDegrees)
                let excess = max(0, diff - slack)
                excessAngles.append(excess)
            }
        }

        guard !excessAngles.isEmpty else { return 100 }

        let averageExcess = excessAngles.reduce(0, +) / Double(excessAngles.count)
        let normalized = min(1, averageExcess / 90)
        let tightening = Double(profile.evaluationTighteningRate)
        let baseScore = max(0, 1 - normalized * tightening)
        let completionRatio = min(1, Double(actual.count) / Double(expected.count))
        return Int(round(baseScore * completionRatio * 100))
    }

    private func scoreStart() -> Int {
        guard let expected = template.strokes.first else { return 0 }
        guard let actualStroke = drawing.strokes.first else { return 0 }
        guard let actualStart = adjustedStartPoint(for: actualStroke, index: 0) else { return 0 }

        let distance = hypot(actualStart.x - expected.startPoint.x,
                             actualStart.y - expected.startPoint.y)
        if distance <= startTolerance {
            return 100
        }
        let overshoot = max(0, distance - startTolerance)
        let scale = max(startTolerance, 1)
        let penalty = min(90, Int(round((overshoot / scale) * 55)))
        return max(0, 100 - penalty)
    }

    private func magnetizedOffset(for index: Int) -> CGVector {
        magnetizedOffsets[index] ?? .zero
    }

    private func adjustedPoints(for stroke: PKStroke, index: Int, step: Int) -> [CGPoint] {
        let points = stroke.sampledPoints(step: step)
        let offset = magnetizedOffset(for: index)
        guard offset.dx != 0 || offset.dy != 0 else { return points }
        return points.map { point in
            CGPoint(x: point.x + offset.dx, y: point.y + offset.dy)
        }
    }

    private func adjustedStartPoint(for stroke: PKStroke, index: Int) -> CGPoint? {
        guard let start = stroke.path.firstLocation else { return nil }
        let offset = magnetizedOffset(for: index)
        return CGPoint(x: start.x + offset.dx, y: start.y + offset.dy)
    }

    private func nearestDistance(from point: CGPoint, to stroke: ScaledStroke) -> CGFloat {
        var nearest = CGFloat.greatestFiniteMagnitude
        for templatePoint in stroke.sampledPoints {
            let distance = hypot(point.x - templatePoint.x, point.y - templatePoint.y)
            if distance < nearest {
                nearest = distance
                if nearest < corridorRadius * 0.25 {
                    break
                }
            }
        }
        return nearest
    }

    private func keyDirectionVectors(for stroke: ScaledStroke) -> [CGVector] {
        directionVectors(from: stroke.points)
    }

    private func keyDirectionVectors(for stroke: PKStroke, index: Int) -> [CGVector] {
        directionVectors(from: adjustedPoints(for: stroke, index: index, step: 3))
    }

    private func directionVectors(from points: [CGPoint]) -> [CGVector] {
        guard points.count >= 4 else { return [] }
        let fractions: [Double] = [0.1, 0.35, 0.6, 0.85]
        return fractions.compactMap { fraction in
            let rawIndex = Int(round(fraction * Double(points.count - 2)))
            let index = min(max(rawIndex, 0), points.count - 2)
            let start = points[index]
            let end = points[index + 1]
            return normalizedVector(dx: end.x - start.x, dy: end.y - start.y)
        }
    }

    private func normalizedVector(dx: CGFloat, dy: CGFloat) -> CGVector? {
        let magnitude = hypot(dx, dy)
        guard magnitude > 0 else { return nil }
        return CGVector(dx: dx / magnitude, dy: dy / magnitude)
    }

    private func angleDifferenceDegrees(_ a: CGVector, _ b: CGVector) -> Double {
        let angleA = atan2(Double(a.dy), Double(a.dx))
        let angleB = atan2(Double(b.dy), Double(b.dx))
        var diff = abs(angleA - angleB)
        if diff > .pi {
            diff = (2 * .pi) - diff
        }
        return diff * 180 / .pi
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
