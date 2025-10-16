import SwiftUI

struct PracticeRowGuides: View {
    let width: CGFloat
    let ascender: CGFloat
    let descender: CGFloat
    let scaledXHeight: CGFloat
    let guideLineWidth: CGFloat

    private var baselineY: CGFloat { ascender }
    private var xHeightY: CGFloat { ascender - scaledXHeight }
    private var descenderY: CGFloat { ascender + descender }

    var body: some View {
        Canvas { context, size in
            let fullWidth = size.width
            let topLine = Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: fullWidth, y: 0))
            }

            let baseline = Path { path in
                path.move(to: CGPoint(x: 0, y: baselineY))
                path.addLine(to: CGPoint(x: fullWidth, y: baselineY))
            }

            let xHeightLine = Path { path in
                path.move(to: CGPoint(x: 0, y: xHeightY))
                path.addLine(to: CGPoint(x: fullWidth, y: xHeightY))
            }

            let descenderLine = Path { path in
                path.move(to: CGPoint(x: 0, y: descenderY))
                path.addLine(to: CGPoint(x: fullWidth, y: descenderY))
            }

            let topColor = Color(red: 0.64, green: 0.74, blue: 0.95)
            let baselineColor = Color(red: 0.48, green: 0.58, blue: 0.89)
            let descenderColor = Color(red: 0.76, green: 0.81, blue: 0.93)

            context.stroke(topLine, with: .color(topColor), lineWidth: guideLineWidth)
            context.stroke(baseline, with: .color(baselineColor), lineWidth: guideLineWidth * 1.2)
            context.stroke(descenderLine, with: .color(descenderColor), lineWidth: guideLineWidth * 0.85)

            let dashedStyle = StrokeStyle(lineWidth: guideLineWidth, lineCap: .round, dash: [4, 6])
            context.stroke(xHeightLine,
                           with: .color(baselineColor.opacity(0.65)),
                           style: dashedStyle)
        }
        .frame(width: width, height: ascender + descender)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Handwriting guides with top, dotted middle, baseline, and descender lines")
    }
}
