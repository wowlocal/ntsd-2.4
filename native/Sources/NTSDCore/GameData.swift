import Foundation

public typealias Fields = [String: String]

extension Dictionary where Key == String, Value == String {
    public func number(_ key: String, _ fallback: Double = 0) -> Double {
        guard let text = self[key]?.split(whereSeparator: \.isWhitespace).first,
              let value = Double(text), value.isFinite else { return fallback }
        return value
    }
    public func integer(_ key: String, _ fallback: Int = 0) -> Int {
        let value = number(key, Double(fallback))
        guard value > Double(Int.min), value < Double(Int.max) else { return fallback }
        return Int(value)
    }
}

public struct SpriteSheet: Codable, Sendable {
    public let first: Int
    public let last: Int
    public let path: String
    public let fields: Fields
}

public struct Frame: Codable, Sendable {
    public let name: String
    public let fields: Fields
    public let blocks: [String: [Fields]]
    public func block(_ name: String) -> [Fields] { blocks[name] ?? [] }

    public init(name: String = "", fields: Fields, blocks: [String: [Fields]] = [:]) {
        self.name = name; self.fields = fields; self.blocks = blocks
    }
}

public struct ObjectDefinition: Codable, Sendable {
    public let id: Int
    public let type: Int
    public let source: String
    public let header: Fields
    public let sheets: [SpriteSheet]
    public let frames: [String: Frame]
    public let frameOccurrences: [FrameOccurrence]?
    public let originalText: String?
    public var name: String { header["name"] ?? URL(fileURLWithPath: source).deletingPathExtension().lastPathComponent }
    public func frame(_ index: Int) -> Frame? { frames[String(index)] }
    public init(id: Int, type: Int = 0, source: String = "fixture", header: Fields = [:],
                sheets: [SpriteSheet] = [], frames: [String: Frame], frameOccurrences: [FrameOccurrence]? = nil,
                originalText: String? = nil) {
        self.id = id; self.type = type; self.source = source; self.header = header
        self.sheets = sheets; self.frames = frames
        self.frameOccurrences = frameOccurrences
        self.originalText = originalText
    }
}

public struct FrameOccurrence: Codable, Sendable {
    public let number: Int
    public let frame: Frame
}

public struct BackgroundDefinition: Codable, Sendable {
    public let id: Int
    public let source: String
    public let header: Fields
    public let layers: [Fields]
    public var name: String { (header["name"] ?? "Arena").replacingOccurrences(of: "_", with: " ") }
}

public struct GameData: Codable, Sendable {
    public let objects: [ObjectDefinition]
    public let backgrounds: [BackgroundDefinition]
    public let files: [String: String]
    public static func load(from url: URL) throws -> GameData {
        try JSONDecoder().decode(GameData.self, from: Data(contentsOf: url))
    }
    public func object(_ id: Int) -> ObjectDefinition? { objects.first { $0.id == id } }
    public func resourcePath(_ path: String) -> String {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        return files[normalized.lowercased()] ?? normalized
    }
}
