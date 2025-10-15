import SwiftUI
import PencilKit
import UIKit

struct PracticeSessionView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore

    let letterId: String

    private let rowAscender: CGFloat = 120
    private let rowDescender: CGFloat = 60
    private let deviationTolerance: CGFloat = 36
    private let startTolerance: CGFloat = 28

    private let enabledModes: [PracticeMode] = [.trace]
    @State private var mode: PracticeMode = .trace
    @State private var template: HandwritingTemplate?
    @State private var scaledTemplate: ScaledTemplate?
    @State private var lastScaledWidth: CGFloat?
    @State private var loadError: String?

    @State private var drawing = PKDrawing()
    @State private var strokeProgress: [CGFloat] = []
    @State private var previousStrokeCount = 0
    @State private var lastWarning: WarningIdentifier?
    @State private var warningMessage: String?

    @State private var scoreResult: ScoreResult?
    @State private var tips: [TipMessage] = []
    @State private var showResultBanner = false
    @State private var hintUsed = false
    @State private var startedAt = Date()
    @State private var unlockMessage: String?

    private var isLeftHanded: Bool {
        dataStore.settings.isLeftHanded
    }

    private var hapticsEnabled: Bool {
        dataStore.settings.hapticsEnabled
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if enabledModes.count > 1 {
                    modeSelector
                }

                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        if let scaled = scaledTemplate(for: proxy.size.width) {
                            PracticeRowGuides(width: proxy.size.width,
                                              ascender: rowAscender,
                                              descender: rowDescender,
                                              scaledXHeight: scaled.scaledXHeight)

                            TemplateOverlayView(strokes: scaled.strokes,
                                                progress: strokeProgress,
                                                mode: mode)

                            PencilCanvasView(drawing: $drawing) { updated in
                                processDrawingChange(updated, scaledTemplate: scaled)
                            }
                            .allowsHitTesting(mode != .trace || strokeProgress.last ?? 0 >= 1)

                            if let warningMessage {
                                WarningToast(text: warningMessage)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    .padding()
                            }
                        } else if let loadError {
                            Text(loadError)
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            ProgressView("Loading template…")
                                .padding()
                        }
                    }
                }
                .frame(height: rowAscender + rowDescender + 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
                .padding(.horizontal, 8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onChange(of: drawing) { _, newDrawing in
                    if newDrawing.strokes.isEmpty {
                        previousStrokeCount = 0
                        lastWarning = nil
                        warningMessage = nil
                        startedAt = Date()
                    }
                }

                if enabledModes.contains(.ghost), mode == .ghost {
                    hintButton
                }

                controlBar

                if showResultBanner, let scoreResult {
                    ScoreBanner(result: scoreResult, tips: tips)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let unlockMessage {
                    UnlockBanner(message: unlockMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTemplateIfNeeded()
            startedAt = Date()
        }
        .onChange(of: template?.id) { _, newId in
            if newId != nil {
                resetSession()
            }
        }
        .onChange(of: dataStore.settings.isLeftHanded) { _, _ in
            scaledTemplate = nil
            lastScaledWidth = nil
            resetSession()
        }
        .onChange(of: mode) { _, newMode in
            handleModeChange(newMode)
        }
        .animation(.easeInOut(duration: 0.3), value: warningMessage)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showResultBanner)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: unlockMessage)
    }

    private var header: some View {
        let mastery = dataStore.mastery(for: letterId)
        return VStack(alignment: .leading, spacing: 8) {
            Text(dataStore.displayName(for: letterId))
                .font(.largeTitle.weight(.bold))

            if mastery.bestScore > 0 {
                Text("Best score \(mastery.bestScore)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Let's get started with Trace mode.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var modeSelector: some View {
        Picker("Mode", selection: $mode) {
            ForEach(PracticeMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Practice mode")
    }

    private var hintButton: some View {
        Button {
            playHintAnimation()
            hintUsed = true
        } label: {
            Label("Show Hint", systemImage: "lightbulb")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Show tracing hint")
    }

    private var controlBar: some View {
        Group {
            if isLeftHanded {
                HStack {
                    Button(action: evaluateAttempt) {
                        Label("Evaluate", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(template == nil)

                    Spacer()

                    Button(role: .destructive, action: resetSession) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                HStack {
                    Button(role: .destructive, action: resetSession) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: evaluateAttempt) {
                        Label("Evaluate", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(template == nil)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func loadTemplateIfNeeded() {
        guard template == nil else { return }
        do {
            template = try HandwritingTemplateLoader.loadTemplate(for: letterId)
        } catch TemplateLoaderError.resourceMissing(let message) {
            loadError = message
        } catch TemplateLoaderError.decodeFailed(let message) {
            loadError = message
        } catch {
            loadError = "Unexpected error loading template: \(error)"
        }
    }

    private func scaledTemplate(for width: CGFloat) -> ScaledTemplate? {
        guard let template, width > 0 else {
            return template != nil ? scaledTemplate : nil
        }

        if let cached = scaledTemplate,
           let cachedWidth = lastScaledWidth,
           abs(cachedWidth - width) < 1 {
            return cached
        }

        let newScaled = ScaledTemplate(template: template,
                                       availableWidth: width,
                                       rowAscender: rowAscender,
                                       rowDescender: rowDescender,
                                       isLeftHanded: isLeftHanded)
        scaledTemplate = newScaled
        lastScaledWidth = width
        strokeProgress = Array(repeating: 0, count: newScaled.strokes.count)
        startAnimationIfNeeded()
        return newScaled
    }

    private func resetSession() {
        drawing = PKDrawing()
        previousStrokeCount = 0
        lastWarning = nil
        warningMessage = nil
        scoreResult = nil
        tips = []
        showResultBanner = false
        hintUsed = false
        unlockMessage = nil
        strokeProgress = Array(repeating: 0, count: scaledTemplate?.strokes.count ?? 0)
        startedAt = Date()
        startAnimationIfNeeded()
    }

    private func handleModeChange(_ mode: PracticeMode) {
        resetSession()
    }

    private func startAnimationIfNeeded() {
        guard let scaledTemplate else { return }
        strokeProgress = Array(repeating: 0, count: scaledTemplate.strokes.count)

        switch mode {
        case .trace:
            animateStrokesSequentially()
        case .ghost, .memory:
            break
        }
    }

    private func animateStrokesSequentially() {
        guard let scaledTemplate else { return }
        let baseDelay = 0.2
        let durationPerStroke = 1.0

        for index in scaledTemplate.strokes.indices {
            let delay = baseDelay + (Double(index) * (durationPerStroke + 0.2))
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: durationPerStroke)) {
                    strokeProgress[index] = 1.0
                }
            }
        }
    }

    private func playHintAnimation() {
        guard let scaledTemplate else { return }
        strokeProgress = Array(repeating: 0, count: scaledTemplate.strokes.count)

        let durationPerStroke = 0.8
        for index in scaledTemplate.strokes.indices {
            let delay = Double(index) * (durationPerStroke + 0.1)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: durationPerStroke)) {
                    strokeProgress[index] = 1.0
                }
            }
        }
    }

    private func processDrawingChange(_ drawing: PKDrawing, scaledTemplate: ScaledTemplate) {
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
            lastWarning = nil
        }

        if let latestStroke = strokes.last {
            let strokeIndex = min(strokes.count - 1, scaledTemplate.strokes.count - 1)
            checkDeviation(stroke: latestStroke,
                           strokeIndex: strokeIndex,
                           templateStroke: scaledTemplate.strokes[strokeIndex])
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
                           message: "Start at the green dot.")
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
                if distance < nearest {
                    nearest = distance
                }
                if nearest < deviationTolerance / 2 {
                    break
                }
            }
            maxDistance = max(maxDistance, nearest)
        }

        if maxDistance > deviationTolerance {
            triggerWarning(.init(strokeIndex: strokeIndex, kind: .deviation),
                           message: "Stay close to the path.")
        }
    }

    private func triggerWarning(_ identifier: WarningIdentifier, message: String) {
        guard lastWarning != identifier else { return }
        lastWarning = identifier
        warningMessage = message
        if hapticsEnabled {
            HapticsManager.shared.warning()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if self.lastWarning == identifier {
                self.warningMessage = nil
            }
        }
    }

    private func evaluateAttempt() {
        guard let scaledTemplate else { return }

        let evaluator = PracticeEvaluator(template: scaledTemplate,
                                          drawing: drawing,
                                          startTolerance: startTolerance,
                                          deviationTolerance: deviationTolerance)
        let result = evaluator.evaluate()
        scoreResult = result
        tips = generateTips(from: result)
        showResultBanner = true

        let completedAt = Date()
        let duration = completedAt.timeIntervalSince(startedAt)

        let drawingData = drawing.dataRepresentation()

        let unlockEvent = dataStore.recordAttempt(letterId: letterId,
                                                  mode: mode,
                                                  result: result,
                                                  tips: tips.map(\.id),
                                                  hintUsed: hintUsed,
                                                  drawingData: drawingData,
                                                  duration: duration,
                                                  startedAt: startedAt,
                                                  completedAt: completedAt)

        if hapticsEnabled {
            if result.total >= 80 {
                HapticsManager.shared.success()
            } else {
                HapticsManager.shared.notice()
            }
        }

        if let event = unlockEvent {
            let displayName = dataStore.displayName(for: event.newlyUnlockedLetterId)
            unlockMessage = "\(displayName) unlocked! Ready when you are."
        }
    }

    private func generateTips(from result: ScoreResult) -> [TipMessage] {
        var tipIds: [String] = []
        if result.start < 80 {
            tipIds.append("start-point")
        }
        if result.order < 80 {
            tipIds.append("stroke-order")
        }
        if result.direction < 80 {
            tipIds.append("direction")
        }
        if result.shape < 80 {
            tipIds.append("shape-tighten")
        }
        tipIds = Array(tipIds.prefix(2))
        return tipIds.compactMap { id in
            guard let text = TipMessage.catalog[id] else { return nil }
            return TipMessage(id: id, text: text)
        }
    }
}

// MARK: - Supporting Views & Types

private struct TemplateOverlayView: View {
    let strokes: [ScaledStroke]
    let progress: [CGFloat]
    let mode: PracticeMode

    var body: some View {
        Group {
            switch mode {
            case .trace:
                traceBody
            case .ghost:
                ghostBody
            case .memory:
                EmptyView()
            }
        }
        .accessibilityHidden(true)
    }

    private var traceBody: some View {
        ZStack {
            ForEach(Array(strokes.enumerated()), id: \.element.id) { index, stroke in
                stroke.path
                    .trim(from: 0, to: min(progress[safe: index] ?? 0, 1))
                    .stroke(Color.blue.opacity(0.85),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

                StartDot(position: stroke.startPoint)
            }
        }
    }

    private var ghostBody: some View {
        ZStack {
            ForEach(strokes) { stroke in
                stroke.path
                    .stroke(Color.blue.opacity(0.18), lineWidth: 6)
                StartDot(position: stroke.startPoint)
                    .opacity(0.6)
            }

            ForEach(Array(strokes.enumerated()), id: \.element.id) { index, stroke in
                stroke.path
                    .trim(from: 0, to: min(progress[safe: index] ?? 0, 1))
                    .stroke(Color.blue.opacity(0.65),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct StartDot: View {
    let position: CGPoint

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 12, height: 12)
            .position(position)
            .accessibilityHidden(true)
    }
}

private struct WarningToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct ScoreBanner: View {
    let result: ScoreResult
    let tips: [TipMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Score")
                    .font(.headline)
                Text("\(result.total)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            }

            HStack(spacing: 16) {
                componentView(title: "Shape", value: result.shape)
                componentView(title: "Order", value: result.order)
                componentView(title: "Direction", value: result.direction)
                componentView(title: "Start", value: result.start)
            }

            if !tips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Try this next:")
                        .font(.subheadline.weight(.semibold))
                    ForEach(tips) { tip in
                        Label(tip.text, systemImage: "lightbulb")
                            .font(.subheadline)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Score \(result.total). Shape \(result.shape). Order \(result.order). Direction \(result.direction). Start \(result.start)." +
            (tips.isEmpty ? "" : " Tips: \(tips.map(\.text).joined(separator: ", ")).")
        )
    }

    private func componentView(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct UnlockBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "sparkles")
            Text(message)
                .font(.subheadline.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemYellow).opacity(0.2)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

private struct TipMessage: Identifiable, Equatable {
    let id: String
    let text: String

    static let catalog: [String: String] = [
        "start-point": "Start at the green dot to build muscle memory.",
        "stroke-order": "Follow the stroke order—write the tail last.",
        "direction": "Trace the loop clockwise to keep the slant consistent.",
        "shape-tighten": "Keep the curve closer to the guide for a tighter shape."
    ]
}

struct ScaledTemplate: Equatable {
    struct Constants {
        static let horizontalPadding: CGFloat = 32
    }

    let strokes: [ScaledStroke]
    let scaledXHeight: CGFloat
    let letterWidth: CGFloat

    init(template: HandwritingTemplate,
         availableWidth: CGFloat,
         rowAscender: CGFloat,
         rowDescender: CGFloat,
         isLeftHanded: Bool) {
        let allPoints = template.strokes.flatMap(\.points)
        let minX = allPoints.map(\.x).min() ?? 0
        let maxX = allPoints.map(\.x).max() ?? 0

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
        self.strokes = sortedStrokes.map { stroke in
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
    }
}

struct ScaledStroke: Identifiable, Equatable {
    let id: String
    let order: Int
    let path: Path
    let points: [CGPoint]
    let startPoint: CGPoint
    let endPoint: CGPoint

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

        let total = Int(
            round(0.40 * Double(shapeScore)
                  + 0.25 * Double(orderScore)
                  + 0.20 * Double(directionScore)
                  + 0.15 * Double(startScore))
        )

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
                  let actualRaw = actualStrokes[index].directionVector else {
                continue
            }

            let expectedVector = expectedRaw.normalized()
            let actualVector = actualRaw.normalized()
            if expectedVector.isZero || actualVector.isZero { continue }

            let dot = max(-1.0, min(1.0, expectedVector.dot(actualVector)))
            total += (dot + 1) / 2 // map -1...1 to 0...1
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

private enum WarningKind: Equatable {
    case start
    case deviation
}

private struct WarningIdentifier: Equatable {
    let strokeIndex: Int
    let kind: WarningKind
}

extension ScaledStroke {
    var directionVector: CGVector? {
        guard let first = points.first, let last = points.last else { return nil }
        return CGVector(dx: last.x - first.x, dy: last.y - first.y)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension PKStroke {
    var directionVector: CGVector? {
        guard let first = path.firstLocation,
              let last = path.lastLocation else { return nil }
        return CGVector(dx: last.x - first.x, dy: last.y - first.y)
    }

    func sampledPoints(step: Int) -> [CGPoint] {
        var result: [CGPoint] = []
        var index = 0
        for point in path {
            if index % max(step, 1) == 0 {
                result.append(point.location)
            }
            index += 1
        }
        if let last = path.lastLocation, result.last != last {
            result.append(last)
        }
        return result
    }
}

private extension CGVector {
    func normalized() -> CGVector {
        let magnitude = self.magnitude
        guard magnitude > 0 else { return .zero }
        let inverse = CGFloat(1 / magnitude)
        return CGVector(dx: dx * inverse, dy: dy * inverse)
    }

    func dot(_ other: CGVector) -> Double {
        Double(dx * other.dx + dy * other.dy)
    }

    var magnitude: Double {
        sqrt(Double(dx * dx + dy * dy))
    }

    var isZero: Bool {
        magnitude == 0
    }
}

private extension PKStrokePath {
    var firstLocation: CGPoint? {
        first?.location
    }

    var lastLocation: CGPoint? {
        var lastPoint: PKStrokePoint?
        for point in self {
            lastPoint = point
        }
        return lastPoint?.location
    }
}

// MARK: - Haptics

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
