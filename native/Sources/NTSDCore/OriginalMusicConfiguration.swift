import Foundation

extension OriginalMatchPreparation {
    /// Consume the shared417170 table/index/counter already owned by this menu.
    /// Stream is an original call-site tag; it does not select an independent RNG.
    mutating func drawMenuRandom(stream: Int32, range: Int32,
                                observe: (OriginalFrontScreenEvent) throws -> Void) throws -> Int32 {
        var random = OriginalRandom(table: try (0..<3000).map { try globals.integer(at: 0x44ff90-Self.globalBase+$0,as: UInt8.self) },
            index: Int(try global(0x450bcc)),counter: Int(try global(0x450c34)),source: "own menu state",sourceSHA256: "")
        try random.validate()
        let index = random.index,counter = random.counter,result = Int32(random.next(Int(range)))
        try setGlobal(0x450bcc,Int32(random.index));try setGlobal(0x450c34,Int32(random.counter))
        try observe(.init("random",[UInt32(bitPattern: stream),UInt32(bitPattern: range),UInt32(bitPattern: result),
            UInt32(index),UInt32(counter),UInt32(random.index),UInt32(random.counter)]))
        return result
    }
}

/// Whole402130..4025a5 configuration/labels. Random consumes417170 on EVERY
/// non-Stage call, even with no input. Stage changes only ON/OFF, leaving path
/// storage untouched. Alternatives to the own Random sequence need wider D.
public enum OriginalMusicConfiguration {
    public static func advance(state: inout OriginalMatchPreparation, mode: Int32, left: Int32, right: Int32,
                               target: UInt32, input: OriginalFrontScreenBodyInput,
                               observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws {
        var candidate = state
        func writeString(_ value: String,_ address: Int) throws {
            for (i,b) in (Array(value.utf8)+[0]).enumerated() { try candidate.globals.write(b,at: address-OriginalMatchPreparation.globalBase+i) }
        }
        try observe(.init("musicConfiguration",[UInt32(bitPattern: mode),UInt32(bitPattern: left),UInt32(bitPattern: right),target]))
        var choice = try candidate.global(0x44f18c)
        if mode == 1 {
            if left != 0 || right != 0 { choice = choice == -1 ? 0 : -1;try candidate.setGlobal(0x44f18c,choice) }
            if choice != -1 { try writeString("ON",0x44f128) }
        } else {
            if right != 0 { choice &+= 1;try candidate.setGlobal(0x44f18c,choice) }
            if choice > 8 { choice = -1;try candidate.setGlobal(0x44f18c,choice) }
            if left != 0 { choice &-= 1;try candidate.setGlobal(0x44f18c,choice) }
            if choice < -1 { choice = 8;try candidate.setGlobal(0x44f18c,choice) }
            let labels = ["Random","Main Theme","Stage 1","Stage 2","Stage 3","Stage 4","Stage 5","Boss","Final Boss"]
            if labels.indices.contains(Int(choice)) { try writeString(labels[Int(choice)],0x44f128) }
            let selected = choice == 0 ? try candidate.drawMenuRandom(stream: 1,range: 8,observe: observe) &+ 1 : choice
            let paths = ["bgm\\main.wma","bgm\\stage1.wma","bgm\\stage2.wma","bgm\\stage3.wma","bgm\\stage4.wma","bgm\\stage5.wma","bgm\\boss1.wma","bgm\\boss2.wma"]
            if (1...8).contains(selected) { try writeString(paths[Int(selected)-1],0x44eed0) }
            else if selected == -1 { try candidate.globals.write(UInt8(0),at: 0x44eed0-OriginalMatchPreparation.globalBase) }
        }
        if choice == -1 {
            try writeString("OFF",0x44f128);try candidate.setGlobal(0x44d010,0)
            try observe(.init("stopMusic"))
            try OriginalMusicPlayback.stop(globals: candidate.globals) { e in
                guard e.kind == .method else { throw OriginalStateError.invalidStorage("Music configuration method") }
                try observe(.init("musicMethod",e.arguments));return .init()
            }
        } else { try candidate.setGlobal(0x44d010,1) }
        let offset = 0x44f128-OriginalMatchPreparation.globalBase
        guard let end = candidate.globals.bytes[offset...].firstIndex(of: 0),candidate.globals.defined[offset...end].allSatisfy({ $0 }) else {
            throw OriginalStateError.invalidStorage("Music configuration label extent")
        }
        let text = Array("Music: ".utf8)+Array(candidate.globals.bytes[offset..<end])
        for (i,b) in (text+[0]).enumerated() { try candidate.globals.write(b,at: 0x44f060-OriginalMatchPreparation.globalBase+i) }
        try observe(.init("format",[UInt32(text.count)],[Array("Music: %s".utf8),text]))
        for (bytes,y,color) in [(text,Int32(3),UInt32(0xd8775a)),(Array("(Press Left/Right to change)".utf8),20,0xa03f22)] {
            try OriginalSurfaceText.draw(bytes,target: target,background: 0,color: color,x: 603,y: y,dcResult: input.dcResult,dc: input.dc) {
                try observe(.init($0.kind.rawValue,$0.arguments,$0.strings))
            }
        }
        state = candidate
    }
}
