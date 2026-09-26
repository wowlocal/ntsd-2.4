// Finite host-only diagnostic. No original execution or production acceptance.
import AppKit
import CryptoKit

func profile(_ space: NSColorSpace?) -> [String:Any] {
    guard let space else { return ["absent":true] }
    var result: [String:Any] = ["name":space.localizedName ?? "unnamed",
        "model":space.colorSpaceModel.rawValue,
        "cgName":space.cgColorSpace?.name.map { $0 as String } ?? "unnamed"]
    if let data = space.iccProfileData {
        result["iccBytes"] = data.count
        result["iccSHA256"] = SHA256.hash(data:data).map { String(format:"%02x", $0) }.joined()
    }
    return result
}

@MainActor final class ProbeView: NSView {
    var image: CGImage!
    var direct = false
    var contexts: [[String:Any]] = []
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        guard let image else { return }
        NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
        let context = NSGraphicsContext.current!
        var observation: [String:Any] = ["screen":context.isDrawingToScreen]
        if !context.isDrawingToScreen {
            observation["cgName"] = context.cgContext.colorSpace?.name.map { $0 as String } ?? "absent"
        }
        contexts.append(observation)
        if direct {
            context.cgContext.interpolationQuality = .none
            context.cgContext.setBlendMode(.copy)
            context.cgContext.draw(image,in:bounds)
        } else {
            NSGraphicsContext.current?.imageInterpolation = .none
            NSImage(cgImage:image,size:bounds.size).draw(in:bounds,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:nil)
        }
    }
}

func makeImage(_ color: UInt32) -> CGImage {
    let w = 794, h = 550
    let words = [UInt32](repeating:color.littleEndian,count:w*h)
    let bytes = words.withUnsafeBufferPointer { Data(buffer:$0) }
    let provider = CGDataProvider(data:bytes as CFData)!
    let space = CGColorSpace(name:CGColorSpace.sRGB)!
    return CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:space,
        bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.noneSkipFirst.rawValue).union(.byteOrder32Little),
        provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
}

func bitmap(_ rep: NSBitmapImageRep) -> [String:Any] {
    let points = [(1,1),(rep.pixelsWide/2,rep.pixelsHigh/2),(rep.pixelsWide-2,rep.pixelsHigh-2)]
    return ["width":rep.pixelsWide,"height":rep.pixelsHigh,
        "bitsPerSample":rep.bitsPerSample,"bitsPerPixel":rep.bitsPerPixel,
        "samplesPerPixel":rep.samplesPerPixel,"bitmapFormat":rep.bitmapFormat.rawValue,
        "space":profile(rep.colorSpace),"spaceName":rep.colorSpaceName.rawValue,
        "cgName":rep.cgImage?.colorSpace?.name.map { $0 as String } ?? "absent",
        "samples":points.map { x,y -> [String:Any] in
            var raw = [UInt](repeating:0,count:rep.samplesPerPixel)
            rep.getPixel(&raw,atX:x,y:y)
            let color = rep.colorAt(x:x,y:y)!
            let srgb = color.usingColorSpace(.sRGB)!
            var components = [CGFloat](repeating:0,count:color.numberOfComponents)
            color.getComponents(&components)
            return ["x":x,"y":y,"raw":raw,"colorSpace":profile(color.colorSpace),
                "components":components,"sRGB":[srgb.redComponent,srgb.greenComponent,srgb.blueComponent,srgb.alphaComponent]]
        }]
}

@main struct Probe {
    @MainActor static func main() throws {
        let output = URL(fileURLWithPath:CommandLine.arguments[1])
        precondition(!FileManager.default.fileExists(atPath:output.path))
        let app = NSApplication.shared
        app.setActivationPolicy(.regular); app.finishLaunching()
        let colors: [UInt32] = [0,1,0xff,0xff0000,0xff00,0x123456,0xffabcdef,0x336699]
        var directImages: [[String:Any]] = []
        for color in colors { directImages.append(["color":color,"bitmap":bitmap(NSBitmapImageRep(cgImage:makeImage(color)))]) }
        var cases: [[String:Any]] = []
        for policy in ["default","sRGB","screen"] {
            let window = NSWindow(contentRect:.init(x:100,y:100,width:794,height:550),
                styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
            window.isReleasedWhenClosed = false
            window.title = "NTSD color diagnostic"
            let view = ProbeView(frame:.init(x:0,y:0,width:794,height:550))
            window.contentView = view; window.center()
            if policy == "sRGB" { window.colorSpace = .sRGB }
            if policy == "screen" { window.colorSpace = window.screen!.colorSpace }
            window.makeKeyAndOrderFront(nil)
            for direct in [false,true] {
                for color in colors {
                    view.direct = direct; view.image = makeImage(color); view.contexts = []
                    view.needsDisplay = true; window.displayIfNeeded()
                    let rep = view.bitmapImageRepForCachingDisplay(in:view.bounds)!
                    view.cacheDisplay(in:view.bounds,to:rep)
                    cases.append(["policy":policy,"directCGContext":direct,"color":color,
                        "windowProfile":profile(window.colorSpace),"screenProfile":profile(window.screen?.colorSpace),
                        "scale":window.backingScaleFactor,"contexts":view.contexts,"bitmap":bitmap(rep)])
                }
            }
            window.close()
        }
        precondition(cases.count == 48 && directImages.count == 8)
        let result: [String:Any] = ["schema":"ntsd-native-color-probe-v1",
            "OS":ProcessInfo.processInfo.operatingSystemVersionString,
            "directImages":directImages,"cases":cases,"originalExecuted":false,"productionAccepted":false]
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:output,options:.withoutOverwriting)
        print("Recorded 8 direct images and 48 native view cases; no production acceptance")
    }
}
