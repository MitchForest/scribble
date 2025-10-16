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

            let midLine = Path { path in
                path.move(to: CGPoint(x: 0, y: xHeightY))
                path.addLine(to: CGPoint(x: fullWidth, y: xHeightY))
            }

            let baseline = Path { path in
                path.move(to: CGPoint(x: 0, y: baselineY))
                path.addLine(to: CGPoint(x: fullWidth, y: baselineY))
            }

            let descenderLine = Path { path in
                path.move(to: CGPoint(x: 0, y: descenderY))
                path.addLine(to: CGPoint(x: fullWidth, y: descenderY))
            }

            let guideBlue = Color(red: 0.35, green: 0.53, blue: 0.86)
            let dashedRed = Color(red: 0.87, green: 0.41, blue: 0.44)

            context.stroke(topLine,
                           with: .color(guideBlue.opacity(0.85)),
                           lineWidth: guideLineWidth)

            context.stroke(baseline,
                           with: .color(guideBlue.opacity(0.85)),
                           lineWidth: guideLineWidth)

            context.stroke(descenderLine,
                           with: .color(guideBlue.opacity(0.65)),
                           lineWidth: guideLineWidth)

            let dashStyle = StrokeStyle(lineWidth: guideLineWidth * 0.7,
                                        lineCap: .round,
                                        dash: [8, 10])
            context.stroke(midLine,
                           with: .color(dashedRed),
                           style: dashStyle)
        }
        .frame(width: width, height: ascender + descender)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Handwriting guides with solid blue top and baseline, dashed red midline, and descender line")
    }
}
