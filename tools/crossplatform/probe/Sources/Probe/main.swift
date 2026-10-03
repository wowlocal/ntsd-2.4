import Foundation
import Dispatch
#if canImport(CryptoKit)
import CryptoKit
let crypto = "CryptoKit"
#else
let crypto = "none"
#endif

var out: [String] = []
func log(_ s: String) { out.append(s); print(s) }
#if os(Linux)
log("os=linux")
#elseif os(Windows)
log("os=windows")
#elseif os(macOS)
log("os=macos")
#endif
log("ptr=\(MemoryLayout<Int>.size) cint=\(MemoryLayout<CInt>.size) clong=\(MemoryLayout<CLong>.size) crypto=\(crypto)")
log("fmt=" + [UInt8](arrayLiteral: 0, 15, 171, 255).map { String(format: "%02x", $0) }.joined())
let re = try! NSRegularExpression(pattern: #"<frame>\s+(-?\d+)\s+.*?<frame_end>"#, options: .dotMatchesLineSeparators)
let text = "<frame> 12 a\nb <frame_end> <frame> -3 x <frame_end>"
let ms = re.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range(at: 1)) }
log("regex=\(ms)")
struct J: Decodable { let a: Int; let b: [String] }
let j = try! JSONDecoder().decode(J.self, from: Data(#"{"a":7,"b":["x","y"]}"#.utf8))
log("json=\(j.a),\(j.b)")
let lock = NSLock(); var n = 0
DispatchQueue.concurrentPerform(iterations: 64) { _ in lock.lock(); n += 1; lock.unlock() }
log("dispatch=\(n)")
if let res = Bundle.module.url(forResource: "Res", withExtension: nil) {
    log("bundle=ok")
    let names = try! FileManager.default.contentsOfDirectory(atPath: res.path)
    log("contents(raw)=\(names)")
    var walked: [String] = []
    if let it = FileManager.default.enumerator(at: res, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]) {
        for case let u as URL in it {
            let v = try! u.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            walked.append("\(u.lastPathComponent):\(v.isDirectory == true ? "d" : v.isRegularFile == true ? "f" : "?")\(v.isSymbolicLink == true ? "l" : "")")
        }
    }
    log("enumerator(raw)=\(walked)")
    log("read=" + (try! String(contentsOf: res.appendingPathComponent("sub/c.txt"), encoding: .utf8)).trimmingCharacters(in: .whitespacesAndNewlines))
} else { log("bundle=missing") }
log("double=\(0.1 + 0.2) \(Double(Float(1) / 3)) \(Int64.max)")
