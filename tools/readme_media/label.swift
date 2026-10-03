// Renders a caption bar for the README side-by-side: label.swift WIDTH HEIGHT OUT.png TITLE [SUBTITLE]
import AppKit

let a = CommandLine.arguments
guard a.count >= 5, let w = Int(a[1]), let h = Int(a[2]) else { print("usage: label WIDTH HEIGHT OUT.png TITLE [SUBTITLE]"); exit(2) }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: w, height: h).fill()
let title = NSAttributedString(string: a[4], attributes: [.font: NSFont.systemFont(ofSize: CGFloat(h) * 0.42, weight: .semibold),
                                                          .foregroundColor: NSColor.white])
var line = NSMutableAttributedString(attributedString: title)
if a.count > 5 {
    line.append(NSAttributedString(string: "  " + a[5], attributes: [.font: NSFont.systemFont(ofSize: CGFloat(h) * 0.34),
                                                                    .foregroundColor: NSColor(white: 0.7, alpha: 1)]))
}
let size = line.size()
line.draw(at: NSPoint(x: (CGFloat(w) - size.width) / 2, y: (CGFloat(h) - size.height) / 2))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[3]))
