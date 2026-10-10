import Foundation
#if os(Windows)
import WinSDK
let os = "windows"
#else
let os = "other"
#endif
print("os=\(os) ptr=\(MemoryLayout<Int>.size) clong=\(MemoryLayout<CLong>.size)")
print("fmt=" + [UInt8](arrayLiteral: 0, 15, 171, 255).map { String(format: "%02x", $0) }.joined())
let re = try! NSRegularExpression(pattern: #"<frame>\s+(-?\d+)\s+.*?<frame_end>"#, options: .dotMatchesLineSeparators)
let text = "<frame> 12 a\nb <frame_end> <frame> -3 x <frame_end>"
print("regex=\(re.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range(at: 1)) })")
print("double=\(0.1 + 0.2) \(Int64.max)")
