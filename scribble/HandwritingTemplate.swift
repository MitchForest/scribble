import Foundation
import CoreGraphics

struct HandwritingTemplate: Decodable {
    struct Metrics: Decodable {
        let unitsPerEm: Double
        let baseline: Double
        let xHeight: Double
        let ascender: Double
        let descender: Double
        let targetSlantDeg: Double?
    }

    struct Stroke: Decodable {
        let id: String
        let order: Int
        let closed: Bool?
        let description: String?
        let points: [CGPoint]
        let start: CGPoint?
        let end: CGPoint?
        let direction: String?

        private enum CodingKeys: String, CodingKey {
            case id, order, closed, description, points, start, end, direction
        }

        init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        order = try container.decode(Int.self, forKey: .order)
        closed = try container.decodeIfPresent(Bool.self, forKey: .closed)
        description = try container.decodeIfPresent(String.self, forKey: .description)

        let rawPoints = try container.decode([[Double]].self, forKey: .points)
        points = rawPoints.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CGPoint(x: pair[0], y: pair[1])
        }

        if let startPair = try container.decodeIfPresent([Double].self, forKey: .start), startPair.count >= 2 {
            start = CGPoint(x: startPair[0], y: startPair[1])
        } else {
            start = points.first
        }

        if let endPair = try container.decodeIfPresent([Double].self, forKey: .end), endPair.count >= 2 {
            end = CGPoint(x: endPair[0], y: endPair[1])
        } else {
            end = points.last
        }

        direction = try container.decodeIfPresent(String.self, forKey: .direction)
        }
    }

    let id: String
    let script: String
    let variant: String
    let metrics: Metrics
    let strokes: [Stroke]
}

extension HandwritingTemplate.Stroke {
    init(id: String, order: Int, points: [CGPoint]) {
        self.id = id
        self.order = order
        self.closed = nil
        self.description = nil
        self.points = points
        self.start = points.first
        self.end = points.last
        self.direction = nil
    }
}

extension HandwritingTemplate {
    init(id: String, script: String = "cursive", variant: String = "test", metrics: Metrics, strokePoints: [[CGPoint]]) {
        self.id = id
        self.script = script
        self.variant = variant
        self.metrics = metrics
        self.strokes = strokePoints.enumerated().map { index, points in
            HandwritingTemplate.Stroke(id: "s\(index + 1)", order: index + 1, points: points)
        }
    }
}

enum TemplateLoaderError: Error {
    case resourceMissing(String)
    case decodeFailed(String)
}

enum HandwritingTemplateLoader {
    private static let baseDirectory = "AppAssets/HandwritingTemplates"
    private static var cache: [String: HandwritingTemplate] = [:]
    private static let cacheLock = NSLock()

    static func loadTemplate(for letterId: String) throws -> HandwritingTemplate {
        cacheLock.lock()
        if let cached = cache[letterId] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let bundle = Bundle.main
        let subdirectory = templateSubdirectory(for: letterId)
        let filename = "\(letterId).json"

        guard let url = bundle.url(forResource: filename,
                                   withExtension: nil,
                                   subdirectory: "\(baseDirectory)/templates/\(subdirectory)") else {
            throw TemplateLoaderError.resourceMissing("Missing template for \(letterId)")
        }

        do {
            let template = try decodeTemplate(from: url)
            cacheLock.lock()
            cache[letterId] = template
            cacheLock.unlock()
            return template
        } catch {
            throw TemplateLoaderError.decodeFailed("Failed to decode template \(letterId): \(error)")
        }
    }

    static func decodeTemplate(from url: URL) throws -> HandwritingTemplate {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(HandwritingTemplate.self, from: data)
    }

    static func preloadTemplates(for letterIds: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            for id in letterIds {
                cacheLock.lock()
                let alreadyCached = cache[id] != nil
                cacheLock.unlock()
                if alreadyCached { continue }
                _ = try? loadTemplate(for: id)
            }
        }
    }

    private static func templateSubdirectory(for letterId: String) -> String {
        if letterId.contains(".lower") {
            return "alpha-lower"
        } else if letterId.contains(".upper") {
            return "alpha-upper"
        } else {
            return ""
        }
    }
}
