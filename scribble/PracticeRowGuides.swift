import SwiftUI

struct PracticeRowGuides: View {
    let width: CGFloat
    let ascender: CGFloat
    let descender: CGFloat
    let scaledXHeight: CGFloat
    let guideLineWidth: CGFloat

    private var baselineY: CGFloat { ascender }
    private var xHeightY: CGFloat { ascender - scaledXHeight }

    var body: some View {
        Canvas { context, size in
            let fullWidth = size.width

            let drawLine: (CGFloat) -> Path = { y in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: fullWidth, y: y))
                }
            }

            let topLine = drawLine(0)
            let midLine = drawLine(xHeightY)
            let baseline = drawLine(baselineY)

            let primaryBlue = Color(red: 0.32, green: 0.53, blue: 0.88)
            let baselineColor = Color(red: 0.16, green: 0.38, blue: 0.72)
            let midlineRed = Color(red: 0.85, green: 0.36, blue: 0.4)

            let topWidth = max(1, guideLineWidth * 0.75)
            let baseWidth = max(1.2, guideLineWidth)
            let dashWidth = max(1, guideLineWidth * 0.5)

            context.stroke(topLine,
                           with: .color(primaryBlue.opacity(0.85)),
                           lineWidth: topWidth)

            context.stroke(baseline,
                           with: .color(baselineColor),
                           lineWidth: baseWidth)

            let dashStyle = StrokeStyle(lineWidth: dashWidth,
                                        lineCap: .round,
                                        dash: [6, 8])
            context.stroke(midLine,
                           with: .color(midlineRed.opacity(0.9)),
                           style: dashStyle)
        }
        .frame(width: width, height: ascender + descender)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Handwriting guides with solid blue top and baseline and a dashed red midline")
    }
}
