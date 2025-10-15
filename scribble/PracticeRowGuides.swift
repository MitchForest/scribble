import SwiftUI

struct PracticeRowGuides: View {
    let width: CGFloat
    let ascender: CGFloat
    let descender: CGFloat
    let scaledXHeight: CGFloat

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

            context.stroke(topLine, with: .color(.primary.opacity(0.35)), lineWidth: 1.5)
            context.stroke(baseline, with: .color(.primary.opacity(0.35)), lineWidth: 1.5)
            context.stroke(descenderLine, with: .color(.primary.opacity(0.2)), lineWidth: 1)

            let dashedStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 6])
            context.stroke(xHeightLine,
                           with: .color(.primary.opacity(0.3)),
                           style: dashedStyle)
        }
        .frame(width: width, height: ascender + descender)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Handwriting guides with top, dotted middle, baseline, and descender lines")
    }
}
