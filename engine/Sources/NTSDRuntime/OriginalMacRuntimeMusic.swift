import Foundation
import NTSDCore

/// Runtime answers for the recovered DirectShow music calls. Graph and interface
/// pointers are opaque runtime identities with one COM reference count per graph.
/// Answers carry no audio effect: `presented()` exposes the committed graph
/// state that `OriginalMacMusicOutput` plays. Graph events (declared, not a
/// Windows observation): the end of a running graph's track queues EC_COMPLETE
/// (1, S_OK, 0) once and names the SetNotifyWindow target; GetEvent with timeout
/// 0 returns it or E_ABORT without outputs. CreateFile of the root-relative
/// graph log fails with access denied, as for a non-administrator Windows user.
@MainActor public final class OriginalMacRuntimeMusic {
    public enum Boundary: Error, Equatable {
        case unsupported(String), arguments(String), unknownInterface(UInt32), released(UInt32), nonASCIIPath
    }
    public enum Interface: UInt8, Equatable { case graph = 0, control = 0xb1, event = 0xb6, position = 0xb2, audio = 0xb3 }
    public struct Operation: Equatable {
        public let event: OriginalMusicEvent, response: OriginalMusicResponse
    }
    static let iidTail: [UInt8] = [0x68,0xa8,0x56,0xd4,0x0a,0xce,0x11,0xb0,0x3a,0,0x20,0xaf,0x0b,0xa7,0x70]
    public static let invalidHandle: Int32 = -1
    private final class Graph {
        var references: UInt32 = 1
        var interfaces: [Interface:UInt32] = [:]
        var file: [UInt8]?, running = false, volume: Int32 = 0
        var seeks = 0, position = 0.0
        var notify: (window: UInt32,message: UInt32,lParam: UInt32)?, flags: UInt32 = 0
        var events: [(code: UInt32,first: UInt32,second: UInt32)] = []
    }
    public static let abort = Int32(bitPattern:0x80004004)
    /// The newest live graph as the output needs it. `seeks` counts
    /// put_CurrentPosition calls; `position` is the last REFTIME in seconds.
    public struct Presented: Equatable {
        public let graph: UInt32, file: [UInt8]?, running: Bool, volume: Int32, seeks: Int, position: Double
    }
    private let identities: OriginalMacResourceIdentityPool, heap: OriginalMacRuntimeHeap
    private var graphs: [UInt32:Graph] = [:], created: [UInt32] = []
    private var owners: [UInt32:(graph: UInt32,interface: Interface)] = [:]
    public private(set) var operations: [Operation] = []
    public private(set) var messages: [[[UInt8]]] = []
    /// Presents MessageBoxA text (text, caption). Each host supplies its own; the
    /// Mac platform's `init(identities:heap:)` shows a modal alert.
    public var present: ([UInt8],[UInt8]) -> Void
    public init(identities: OriginalMacResourceIdentityPool,heap: OriginalMacRuntimeHeap,
                present: @escaping ([UInt8],[UInt8]) -> Void) {
        self.identities = identities; self.heap = heap; self.present = present
    }
    public func interface(_ pointer: UInt32) -> Interface? { owners[pointer]?.interface }
    public func renderedFile(_ pointer: UInt32) -> [UInt8]? {
        owners[pointer].flatMap { graphs[$0.graph]?.file }
    }
    public func isRunning(_ pointer: UInt32) -> Bool { owners[pointer].flatMap { graphs[$0.graph]?.running } ?? false }
    public func volume(_ pointer: UInt32) -> Int32? { owners[pointer].flatMap { graphs[$0.graph]?.volume } }
    /// The WndProc callback's GetEvent (event+20, timeout 0) and methods.
    public func graph(_ q: OriginalGraphEvents.Request) throws -> OriginalGraphEvents.Response {
        switch q.kind {
        case .getEvent:
            try require(q.arguments.count == 3 && q.arguments[1] == 0x20 && q.arguments[2] == 0,"GetEvent")
            let (graph,kind) = try live(q.arguments[0]); try require(kind == .event,"GetEvent interface")
            let response: OriginalGraphEvents.Response
            if graph.events.isEmpty { response = .init(result:Self.abort) }
            else { let e = graph.events.removeFirst(); response = .init(result:0,code:e.code,first:e.first,second:e.second) }
            graphOperations.append(.init(request:q,response:response)); return response
        case .method:
            let response = OriginalGraphEvents.Response(result:try answer(.init(.method,q.arguments)).result)
            graphOperations.append(.init(request:q,response:response)); return response
        case .windowDefault: throw Boundary.unsupported("graph windowDefault")
        }
    }
    public struct GraphOperation: Equatable { public let request: OriginalGraphEvents.Request, response: OriginalGraphEvents.Response }
    public private(set) var graphOperations: [GraphOperation] = []
    /// The output reached the end of `token`'s track: queue EC_COMPLETE once
    /// while the graph runs and return the notification to post, if enabled.
    public func complete(_ token: UInt32) -> (window: UInt32,message: UInt32,lParam: UInt32)? {
        guard let graph = graphs[token],graph.references > 0,graph.running else { return nil }
        graph.events.append((1,0,0))
        return graph.flags == 0 ? graph.notify : nil
    }
    public func presented() -> Presented? {
        guard let token = created.last(where: { (graphs[$0]?.references ?? 0) > 0 }),let g = graphs[token] else { return nil }
        return .init(graph:token,file:g.file,running:g.running,volume:g.volume,seeks:g.seeks,position:g.position)
    }
    private func live(_ pointer: UInt32) throws -> (Graph,Interface) {
        guard let owner = owners[pointer],let graph = graphs[owner.graph] else { throw Boundary.unknownInterface(pointer) }
        guard graph.references > 0 else { throw Boundary.released(pointer) }
        return (graph,owner.interface)
    }
    private func require(_ valid: Bool,_ what: String) throws { if !valid { throw Boundary.arguments(what) } }
    public func answer(_ e: OriginalMusicEvent) throws -> OriginalMusicResponse {
        let a = e.arguments,response: OriginalMusicResponse
        switch e.kind {
        case .createInstance:
            // CoCreateInstance(CLSID_FilterGraph, NULL, CLSCTX_INPROC_SERVER, IID_IGraphBuilder, &out)
            try require(a == [0x44a2a4,0,1,0x44a254,0x44f040] && e.strings.isEmpty,"createInstance")
            let token = try identities.take(),graph = Graph(); graph.interfaces[.graph] = token
            graphs[token] = graph; owners[token] = (token,.graph); created.append(token)
            response = .init(result:0,pointer:token)
        case .queryInterface:
            try require(a.count == 1 && e.strings.count == 1 && e.strings[0].count == 16 && Array(e.strings[0].dropFirst()) == Self.iidTail,"queryInterface")
            guard let kind = Interface(rawValue:e.strings[0][0]),kind != .graph else { throw Boundary.unsupported("interface \(e.strings[0][0])") }
            let (graph,_) = try live(a[0]),root = owners[a[0]]!.graph
            let token: UInt32
            if let existing = graph.interfaces[kind] { token = existing }
            else { token = try identities.take(); graph.interfaces[kind] = token; owners[token] = (root,kind) }
            graph.references += 1
            response = .init(result:0,pointer:token)
        case .audioVolumeRead:
            try require(a.count == 1,"get_Volume")
            let (graph,kind) = try live(a[0]); try require(kind == .audio,"get_Volume interface")
            response = .init(result:0,pointer:UInt32(bitPattern:graph.volume))
        case .method:
            try require(a.count >= 2,"method")
            let (graph,kind) = try live(a[0]),offset = a[1],args = Array(a.dropFirst(2))
            switch (kind,offset) {
            case (_,8):
                try require(args.isEmpty,"Release"); graph.references -= 1
                response = .init(result:Int32(bitPattern:graph.references))
            case (.graph,0x3c): try require(args.count == 1,"SetLogFile"); response = .init(result:0)
            case (.graph,0x34):
                try require(args.count == 2 && args[1] == 0 && e.strings.count == 1,"RenderFile")
                let wide = e.strings[0]
                try require(wide.count >= 2 && wide.count%2 == 0 && wide.suffix(2) == [0,0],"RenderFile path")
                var path: [UInt8] = []
                for i in stride(from:0,to:wide.count-2,by:2) {
                    guard wide[i+1] == 0,wide[i] != 0,wide[i] < 0x80 else { throw Boundary.nonASCIIPath }
                    path.append(wide[i])
                }
                graph.file = path; response = .init(result:0)
            case (.event,0x34):
                try require(args.count == 3,"SetNotifyWindow")
                graph.notify = args[0] == 0 ? nil : (args[0],args[1],args[2]); response = .init(result:0)
            case (.event,0x38): try require(args.count == 1,"SetNotifyFlags"); graph.flags = args[0]; response = .init(result:0)
            case (.event,0x30): try require(args.count == 3,"FreeEventParams"); response = .init(result:0)
            case (.control,0x1c): try require(args.isEmpty,"Run"); graph.running = true; response = .init(result:0)
            case (.control,0x24): try require(args.isEmpty,"Stop"); graph.running = false; response = .init(result:0)
            case (.position,0x20):
                try require(args.count == 2,"put_CurrentPosition")
                let seconds = Double(bitPattern:UInt64(args[1]) << 32 | UInt64(args[0]))
                try require(seconds.isFinite && seconds >= 0,"put_CurrentPosition time")
                graph.seeks += 1; graph.position = seconds; response = .init(result:0)
            case (.audio,0x1c):
                try require(args.count == 1,"put_Volume"); let level = Int32(bitPattern:args[0])
                try require(level <= 0 && level >= -10000,"put_Volume range"); graph.volume = level; response = .init(result:0)
            default: throw Boundary.unsupported("method \(kind) \(String(offset,radix:16))")
            }
        case .createFile:
            try require(a == [0x40000000,0,0,2,0x80,0] && e.strings.count == 1,"createFile")
            response = .init(result:Self.invalidHandle)
        case .allocate:
            try require(a.count == 1 && e.strings.isEmpty,"allocate")
            let value = try heap.allocate(Int(a[0])); response = .init(result:0,pointer:value.address,bytes:value.backing)
        case .convert:
            // MultiByteToWideChar(CP_ACP, 0, path, -1, out, count), ASCII only.
            try require(a.count == 5 && a[0] == 0 && a[1] == 0 && a[2] == UInt32.max && e.strings.count == 1,"convert")
            let path = e.strings[0]
            guard path.allSatisfy({ $0 != 0 && $0 < 0x80 }) else { throw Boundary.nonASCIIPath }
            try require(Int(a[4]) >= path.count+1,"convert capacity")
            var wide: [UInt8] = []
            for byte in path+[0] { wide.append(byte); wide.append(0) }
            let written: [UInt8] = a[3] == 0 ? [] : wide
            response = .init(result:Int32(path.count+1),bytes:written)
        case .closeHandle:
            try require(a.count == 1,"closeHandle")
            // CloseHandle(INVALID_HANDLE_VALUE) names the current-process pseudo
            // handle; the recovered caller ignores this result.
            response = .init(result:1)
        case .message:
            try require(e.strings.count == 2,"MessageBoxA")
            messages.append(e.strings); present(e.strings[0],e.strings[1]); response = .init(result:1)
        case .helper,.format:
            throw Boundary.unsupported("\(e.kind) is not an external request")
        }
        operations.append(.init(event:e,response:response))
        return response
    }
}
