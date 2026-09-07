import AppKit
import SpriteKit
import AVFoundation
import NTSDCore

final class Assets {
    let game: GameData
    let root: URL
    private var images: [String: CGImage] = [:]
    private var textures: [String: SKTexture] = [:]
    private var players: [AVAudioPlayer] = []
    private(set) var missing: Set<String> = []
    var muted = false

    init(game: GameData, root: URL) { self.game = game; self.root = root }

    func url(_ path: String) -> URL { root.appendingPathComponent(game.resourcePath(path)) }

    func image(_ path: String, transparent: Bool = true) -> CGImage? {
        let key = path.lowercased() + (transparent ? ":alpha" : ":solid")
        if let cached = images[key] { return cached }
        guard let source = NSImage(contentsOf: url(path)),
              let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            missing.insert(path); return nil
        }
        guard transparent else { images[key] = cg; return cg }
        let width = cg.width, height = cg.height
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let bytes = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        // LF uses exact black as its sprite color key. Do not remove near-black
        // outlines or use the magenta key from the superseded web-port plan.
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            if bytes[i] == 0 && bytes[i + 1] == 0 && bytes[i + 2] == 0 { bytes[i + 3] = 0 }
        }
        let result = ctx.makeImage()
        images[key] = result
        return result
    }

    func texture(_ path: String, transparent: Bool = true) -> SKTexture? {
        let key = path.lowercased() + (transparent ? ":alpha" : ":solid")
        if let cached = textures[key] { return cached }
        guard let cg = image(path, transparent: transparent) else { return nil }
        let texture = SKTexture(cgImage: cg)
        texture.filteringMode = .nearest
        textures[key] = texture
        return texture
    }

    func sprite(_ definition: ObjectDefinition, picture: Int) -> SKTexture? {
        guard let sheet = definition.sheets.first(where: { $0.first <= picture && picture <= $0.last }) else { return nil }
        let key = "\(definition.id):\(picture)"
        if let cached = textures[key] { return cached }
        guard let cg = image(sheet.path) else { return nil }
        let width = sheet.fields.integer("w", 79), height = sheet.fields.integer("h", 79)
        let columns = max(1, sheet.fields.integer("row", 10))
        let offset = picture - sheet.first
        let rect = CGRect(x: offset % columns * (width + 1), y: offset / columns * (height + 1),
                          width: width, height: height)
        guard rect.maxX <= CGFloat(cg.width), rect.maxY <= CGFloat(cg.height),
              let cropped = cg.cropping(to: rect) else { missing.insert(key); return nil }
        let texture = SKTexture(cgImage: cropped)
        texture.filteringMode = .nearest
        textures[key] = texture
        return texture
    }

    func sound(_ path: String) {
        guard !muted else { return }
        players.removeAll { !$0.isPlaying }
        guard players.count < 32 else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url(path))
            player.volume = 0.65; player.play(); players.append(player)
        } catch { missing.insert(path) }
    }

    func stopSounds() { players.forEach { $0.stop() }; players.removeAll() }
}
