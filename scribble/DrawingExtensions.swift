import CoreGraphics
import PencilKit

extension PKStrokePath {
    var firstLocation: CGPoint? {
        first?.location
    }
}

extension PKStroke {
    func sampledPoints(step: Int) -> [CGPoint] {
        var result: [CGPoint] = []
        var index = 0
        for point in path {
            if index % max(step, 1) == 0 {
                result.append(point.location)
            }
            index += 1
        }
        if let last = path.last?.location, result.last != last {
            result.append(last)
        }
        return result
    }

    var directionVector: CGVector? {
        guard let first = path.firstLocation,
              let last = path.last?.location else { return nil }
        return CGVector(dx: last.x - first.x, dy: last.y - first.y)
    }
}

extension CGVector {
    func normalized() -> CGVector {
        let magnitude = sqrt(Double(dx * dx + dy * dy))
        guard magnitude > 0 else { return .zero }
        let inverse = CGFloat(1 / magnitude)
        return CGVector(dx: dx * inverse, dy: dy * inverse)
    }

    func dot(_ other: CGVector) -> Double {
        Double(dx * other.dx + dy * other.dy)
    }

    var isZero: Bool {
        dx == 0 && dy == 0
    }
}
