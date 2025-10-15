import CoreGraphics
import PencilKit

enum StartPointGate {
    static func isStartValid(startPoint: CGPoint, expectedStart: CGPoint, tolerance: CGFloat) -> Bool {
        distanceBetween(startPoint, expectedStart) <= tolerance
    }

    static func removeLastStroke(from drawing: PKDrawing) -> PKDrawing {
        guard !drawing.strokes.isEmpty else { return PKDrawing() }
        return PKDrawing(strokes: Array(drawing.strokes.dropLast()))
    }

    private static func distanceBetween(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
