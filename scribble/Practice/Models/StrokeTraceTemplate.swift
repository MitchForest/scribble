import Foundation
import CoreGraphics

struct StrokeTraceTemplate {
    struct Stroke {
        let id: String
        let order: Int
        let points: [CGPoint]
        let startPoint: CGPoint
        let endPoint: CGPoint
    }

    let strokes: [Stroke]
}
