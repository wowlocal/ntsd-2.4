import AppKit
import SpriteKit
import NTSDCore

/// A static source-data viewer. It intentionally has no guessed game clock,
/// movement, collisions, AI, damage, or automatic state transitions.
final class OriginalScene: SKScene {
    let assets: Assets
    private let picture = SKSpriteNode()
    private let boxes = SKNode()
    private let caption = SKLabelNode(fontNamed: "Menlo")
    var showBoxes = true
    var mirrored = false

    init(assets: Assets) {
        self.assets = assets
        super.init(size: CGSize(width: 800, height: 560))
        scaleMode = .aspectFit
        backgroundColor = NSColor(calibratedWhite: 0.09, alpha: 1)
        let horizontal = SKShapeNode(path: CGPath(rect: CGRect(x: 30, y: 150, width: 740, height: 1), transform: nil))
        horizontal.strokeColor = NSColor(white: 0.28, alpha: 1); addChild(horizontal)
        let vertical = SKShapeNode(path: CGPath(rect: CGRect(x: 400, y: 40, width: 1, height: 460), transform: nil))
        vertical.strokeColor = NSColor(white: 0.2, alpha: 1); addChild(vertical)
        addChild(picture); addChild(boxes)
        caption.fontSize = 14; caption.position = CGPoint(x: 400, y: 520); addChild(caption)
        let note = SKLabelNode(fontNamed: "ArialMT")
        note.text = "Оригинальный кадр DAT • масштаб ×3 • без симуляции боя"
        note.fontSize = 13; note.fontColor = .lightGray; note.position = CGPoint(x: 400, y: 22); addChild(note)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func display(_ object: ObjectDefinition, occurrence: FrameOccurrence) {
        boxes.removeAllChildren()
        let frame = occurrence.frame
        caption.text = "\(object.name)  /  frame \(occurrence.number)  /  \(frame.name)"
        guard let texture = assets.sprite(object, picture: frame.fields.integer("pic")) else {
            picture.isHidden = true
            caption.text! += "  [нет спрайта pic=\(frame.fields["pic"] ?? "?")]"
            return
        }
        picture.isHidden = false; picture.texture = texture; picture.size = texture.size()
        picture.anchorPoint = CGPoint(x: frame.fields.number("centerx") / picture.size.width,
                                      y: (picture.size.height - frame.fields.number("centery")) / picture.size.height)
        picture.position = CGPoint(x: 400, y: 150)
        picture.xScale = mirrored ? -3 : 3; picture.yScale = 3
        guard showBoxes else { return }
        for (kind, color) in [("bdy", NSColor.systemGreen), ("itr", NSColor.systemRed)] {
            for block in frame.block(kind) {
                let x = block.number("x") - frame.fields.number("centerx")
                let y = block.number("y") - frame.fields.number("centery")
                let w = block.number("w"), h = block.number("h")
                guard abs(x) < 2000, abs(y) < 2000, w > 0, h > 0, w < 2000, h < 2000 else { continue }
                let box = SKShapeNode(rect: CGRect(x: 400 + (mirrored ? -x-w : x)*3,
                                                   y: 150 - (y+h)*3, width: w*3, height: h*3))
                box.strokeColor = color; box.lineWidth = 1.5
                box.fillColor = color.withAlphaComponent(0.08); boxes.addChild(box)
            }
        }
    }
}
