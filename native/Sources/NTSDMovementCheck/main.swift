import Foundation
import NTSDCore

struct Document: Decodable {
    let header: Fields, definitions: [String], cases: [Case]
    struct Case: Decodable {
        let label: String, initial: [String: Double], inputs: [UInt8], states: [MovementState]
    }
}
do {
    let doc = try JSONDecoder().decode(Document.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    var ticks = 0, failures = 0
    for c in doc.cases {
        var initial = MovementState()
        initial.x = c.initial["x"] ?? initial.x; initial.z = c.initial["z"] ?? initial.z
        initial.ix = Int(initial.x); initial.iz = Int(initial.z)
        var engine = try OriginalMovement(header: doc.header, definitions: doc.definitions, initial: initial)
        for (i, mask) in c.inputs.enumerated() {
            let result = engine.tick(MovementInput(rawValue: mask)); ticks += 1
            if result != c.states[i] {
                failures += 1
                if failures <= 5 {
                    print("Mismatch \(c.label) tick \(i) input \(mask)")
                    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                    print("native:", String(data: try encoder.encode(result), encoding: .utf8)!)
                    print("oracle:", String(data: try encoder.encode(c.states[i]), encoding: .utf8)!)
                }
                break
            }
        }
    }
    guard failures == 0 else { print("\(failures) failing sequences"); exit(1) }
    print("Native movement matches \(ticks) original x86 ticks across \(doc.cases.count) sequences (exact numbers, frames, buffers and sounds).")
} catch { fputs("Movement check: \(error)\n", stderr); exit(1) }
