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

            let guideColor = Color(red: 0.32, green: 0.53, blue: 0.88)
            let midlineRed = Color(red: 0.87, green: 0.50, blue: 0.52)

            let primaryWidth = max(1, guideLineWidth * 0.72)
            let dashWidth = max(0.6, guideLineWidth * 0.32)

            let topColor = guideColor.opacity(0.78)
            let baselineColor = guideColor.opacity(0.78)

            context.stroke(topLine,
                           with: .color(topColor),
                           lineWidth: primaryWidth)

            context.stroke(baseline,
                           with: .color(baselineColor),
                           lineWidth: primaryWidth)

            let dashStyle = StrokeStyle(lineWidth: dashWidth,
                                        lineCap: .round,
                                        dash: [6, 10])
            context.stroke(midLine,
                           with: .color(midlineRed.opacity(0.55)),
                           style: dashStyle)
        }
        .frame(width: width, height: ascender + descender)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Handwriting guides with solid blue top and baseline and a dashed red midline")
    }
}
