import Foundation

struct HandwritingManifest: Decodable {
    struct GlyphSet: Decodable {
        let name: String
        let glyphs: [String]
    }

    let version: String
    let sets: [GlyphSet]
}

enum HandwritingAssets {
    private static let manifestRelativePath = "AppAssets/HandwritingTemplates/manifest.json"

    static func currentVersion() -> String {
        if let url = manifestURL(in: .main), let manifest = try? decodeManifest(from: url) {
            return manifest.version
        }

        // Fallback for previews/tests when bundled resources are unavailable.
        if let srcRoot = ProcessInfo.processInfo.environment["SRCROOT"] {
            let fallbackURL = URL(fileURLWithPath: srcRoot)
                .appendingPathComponent("scribble")
                .appendingPathComponent(manifestRelativePath)
            if let manifest = try? decodeManifest(from: fallbackURL) {
                return manifest.version
            }
        }

        return "unknown"
    }

    private static func manifestURL(in bundle: Bundle) -> URL? {
        let components = manifestRelativePath.split(separator: "/").map(String.init)
        guard let fileName = components.last else { return nil }
        let subdirectory = components.dropLast().joined(separator: "/")
        return bundle.url(forResource: fileName, withExtension: nil, subdirectory: subdirectory)
    }

    private static func decodeManifest(from url: URL) throws -> HandwritingManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(HandwritingManifest.self, from: data)
    }
}
