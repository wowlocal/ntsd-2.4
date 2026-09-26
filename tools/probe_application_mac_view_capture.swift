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

func rgba(_ color: NSColor) -> [Double] {
    let c = color.usingColorSpace(.sRGB)!
    return [Double(c.redComponent),Double(c.greenComponent),Double(c.blueComponent),Double(c.alphaComponent)]
}
func rawPixel(_ rep: NSBitmapImageRep,_ x: Int,_ y: Int) -> [UInt] {
    var v = [UInt](repeating:0,count:rep.samplesPerPixel); rep.getPixel(&v,atX:x,y:y); return v
}
func pattern(_ colors: [UInt32]) -> CGImage {
    let w = 794,h = 550
    var words = [UInt32](repeating:0,count:w*h)
    for y in 0..<h { for x in 0..<w { words[y*w+x] = colors[(y*4/h)*4+x*4/w].littleEndian } }
    let data = words.withUnsafeBufferPointer { Data(buffer:$0) }
    return CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,
        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.noneSkipFirst.rawValue).union(.byteOrder32Little),
        provider:CGDataProvider(data:data as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
}
@main struct CaptureControls {
    @MainActor static func main() throws {
        let output = URL(fileURLWithPath:CommandLine.arguments[1])
        precondition(!FileManager.default.fileExists(atPath:output.path))
        NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.finishLaunching()
        let colors: [UInt32] = [0,1,0xff,0xff0000,0xff00,0x123456,0xffabcdef,0x336699,
            0x808080,0xffffff,0x010203,0xfedcba,0x7f00ff,0x32cd71,0x97412e,0x4da870]
        let patterns = [colors,Array(colors.reversed())]
        var failures: [String] = [], records: [[String:Any]] = [], ownership: [Bool] = []
        let tolerance = 2.0/255
        func check(_ a: [Double],_ b: [Double],_ name: String) {
            if a.count != b.count || zip(a,b).contains(where:{ abs($0-$1) > tolerance }) { failures.append(name) }
        }
        func inspect(_ rep: NSBitmapImageRep,_ colors: [UInt32],_ label: String) throws -> OriginalMacViewCapture {
            precondition(rep.bitsPerSample == 8 && [3,4].contains(rep.samplesPerPixel))
            let capture = try OriginalMacViewCapture(rep)
            precondition(capture.pixelsWide == rep.pixelsWide && capture.pixelsHigh == rep.pixelsHigh)
            var samples: [[String:Any]] = []
            for i in 0..<16 {
                let x = (2*(i%4)+1)*rep.pixelsWide/8,y = (2*(i/4)+1)*rep.pixelsHigh/8
                let raw = rawPixel(rep,x,y)
                precondition(raw.count == 3 || raw[3] == 255)
                var components = raw.prefix(3).map { CGFloat($0)/255 }; components.append(1)
                let reference = components.withUnsafeBufferPointer { NSColor(colorSpace:rep.colorSpace,components:$0.baseAddress!,count:4) }
                let expected = [16,8,0].map { Double((colors[i] >> $0)&255)/255 }+[1]
                let actual = rgba(capture.colorAt(x:x,y:y)!), control = rgba(reference)
                check(actual,expected,label+" expected tile " + String(i))
                check(actual,control,label+" ICC control tile " + String(i))
                check(control,expected,label+" control expected tile " + String(i))
                samples.append(["x":x,"y":y,"raw":raw,"expected":expected,"actual":actual,
                    "profileAwareControl":control,"legacy":rgba(rep.colorAt(x:x,y:y)!)])
            }
            records.append(["label":label,"width":rep.pixelsWide,"height":rep.pixelsHigh,
                "profile":profile(rep.colorSpace),"samples":samples])
            return capture
        }
        for (i,colors) in patterns.enumerated() {
            let rep = NSBitmapImageRep(cgImage:pattern(colors)), capture = try inspect(rep,colors,"direct-"+String(i))
            let x = rep.pixelsWide/8,y = rep.pixelsHigh/8,before = rgba(capture.colorAt(x:x,y:y)!)
            var white = [UInt](repeating:255,count:rep.samplesPerPixel);rep.setPixel(&white,atX:x,y:y)
            let owned = rgba(capture.colorAt(x:x,y:y)!) == before && rawPixel(rep,x,y) == white
            ownership.append(owned);if !owned { failures.append("snapshot ownership " + String(i)) }
        }
        for policy in ["default","sRGB","screen"] {
            let window = NSWindow(contentRect:.init(x:100,y:100,width:794,height:550),
                styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
            window.isReleasedWhenClosed = false;window.title = "NTSD profile-aware capture controls"
            let view = ProbeView(frame:.init(x:0,y:0,width:794,height:550));window.contentView=view;window.center()
            if policy == "sRGB" { window.colorSpace = .sRGB }
            if policy == "screen" { window.colorSpace = window.screen!.colorSpace }
            window.makeKeyAndOrderFront(nil)
            for (i,colors) in patterns.enumerated() {
                view.image=pattern(colors);view.needsDisplay=true;window.displayIfNeeded()
                let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!;view.cacheDisplay(in:view.bounds,to:rep)
                _ = try inspect(rep,colors,policy+"-"+String(i))
            }
            window.close()
        }
        let bytes: [UInt8] = [0,0,0,0,32,16,8,64,64,32,16,128,255,128,64,255]
        let image = CGImage(width:2,height:2,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:8,
            space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue).union(.byteOrder32Big),
            provider:CGDataProvider(data:Data(bytes) as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
        let rep = NSBitmapImageRep(cgImage:image), capture = try OriginalMacViewCapture(rep)
        var alphaSamples: [[String:Any]] = []
        for i in 0..<4 {
            let a=Double(bytes[i*4+3]),expected = a == 0 ? [0.0,0,0,0] : (0..<3).map { Double(bytes[i*4+$0])/a }+[a/255]
            let actual=rgba(capture.colorAt(x:i%2,y:i/2)!)
            check(actual,expected,"alpha " + String(i));alphaSamples.append(["actual":actual,"expected":expected])
        }
        let bounds=[(-1,0),(0,-1),(2,0),(0,2)].map { capture.colorAt(x:$0.0,y:$0.1) == nil }
        if !bounds.allSatisfy({$0}) { failures.append("bounds") }
        var missingRejected=false,budgetRejected=false
        do { _ = try OriginalMacViewCapture(NSBitmapImageRep()) } catch OriginalMacViewCapture.Boundary.image { missingRejected=true }
        do { _ = try OriginalMacViewCapture(rep,maximumBytes:1) } catch OriginalMacViewCapture.Boundary.size { budgetRejected=true }
        if !missingRejected || !budgetRejected { failures.append("capture boundaries") }
        let result: [String:Any] = ["schema":"ntsd-profile-aware-capture-controls-v1","colors":colors,
            "records":records,"alpha":alphaSamples,"ownership":ownership,"bounds":bounds,
            "missingRejected":missingRejected,"budgetRejected":budgetRejected,"failures":failures,
            "tolerance":tolerance,"independentReview":false,"productionAccepted":false,"originalExecuted":false]
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:output,options:.withoutOverwriting)
        print("Capture controls: \(records.count) opaque records, 4 alpha samples, failures \(failures)")
        exit(failures.isEmpty ? 0 : 1)
    }
}
