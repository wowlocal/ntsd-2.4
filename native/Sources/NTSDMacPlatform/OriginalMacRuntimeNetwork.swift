import Foundation
import NTSDCore

/// The app's Winsock for the original's network code (NETWORK_PLAY_PLAN.md):
/// main-menu requests (402b60, row 2's bind/listen) answered through
/// `OriginalMacWinsock`, and its FD_* notifications posted as the window's
/// 0x401 messages.
public final class OriginalMacRuntimeNetwork {
    public let winsock = OriginalMacWinsock()
    /// gethostbyname's hostent: a nonzero declared token; its contents are the
    /// address list answered with it.
    public static let hostEntry: UInt32 = 0x0d0e_0001
    public private(set) var requests: [OriginalMainMenuEvent] = []
    public private(set) var notificationRequestCount = 0
    public private(set) var clientRequestCount = 0
    /// An explicit local-address response for controlled app tests. The normal
    /// app uses the Mac resolver; the engine still selects and binds its address.
    private let localAddresses: [UInt32]?
    public init(localAddresses: [UInt32]? = nil) { self.localAddresses = localAddresses }
    public enum Boundary: Error, Equatable { case malformed(String) }

    /// Original428420's replies. A successful lookup carries its first owned
    /// address; short/error receives are returned exactly as the OS supplies.
    public func answer(_ q: OriginalNetworkClient.Request) throws -> OriginalNetworkClient.Response {
        let a = q.arguments
        clientRequestCount += 1
        func host(_ addresses: [UInt32]?) -> OriginalNetworkClient.Response {
            guard let address = addresses?.first else { return .init() }
            return .init(result:Int32(bitPattern:Self.hostEntry),hostAddress:address)
        }
        switch q.kind {
        case .closeSocket:
            guard a.count == 1,q.bytes.isEmpty else { throw Boundary.malformed("client closeSocket") }
            return .init(result:winsock.close(a[0]))
        case .socket:
            guard a == [2,1,6],q.bytes.isEmpty else { throw Boundary.malformed("client socket") }
            return .init(result:Int32(bitPattern:winsock.socket(family:2,type:1,protocol:6)))
        case .hostLookup:
            guard a.isEmpty else { throw Boundary.malformed("client hostLookup") }
            return host(winsock.hostAddresses(q.bytes))
        case .hostByAddress:
            guard a == [4,2],q.bytes.count == 4 else { throw Boundary.malformed("client hostByAddress") }
            let address = q.bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset*8) }
            return host(winsock.hostAddresses(address:address))
        case .addressWord:
            guard a.isEmpty else { throw Boundary.malformed("client addressWord") }
            return .init(result:Int32(bitPattern:OriginalMacWinsock.address(q.bytes)))
        case .htons:
            guard a.count == 1,q.bytes.isEmpty else { throw Boundary.malformed("client htons") }
            return .init(result:Int32(OriginalMacWinsock.htons(UInt16(truncatingIfNeeded:a[0]))))
        case .connect:
            guard a.count == 2,a[1] == 16,q.bytes.count == 16,q.bytes[0] == 2,q.bytes[1] == 0 else { throw Boundary.malformed("client connect") }
            let b = q.bytes,port = UInt16(b[2]) << 8 | UInt16(b[3])
            let address = UInt32(b[4]) | UInt32(b[5]) << 8 | UInt32(b[6]) << 16 | UInt32(b[7]) << 24
            return .init(result:winsock.connect(a[0],address:address,port:port))
        case .send:
            guard a.count == 3,a[1] == q.bytes.count,a[2] == 0 else { throw Boundary.malformed("client send") }
            return .init(result:winsock.send(a[0],q.bytes))
        case .receive:
            guard a.count == 3,[100,77,3001].contains(a[1]),a[2] == 0,q.bytes.isEmpty else { throw Boundary.malformed("client receive") }
            let r = winsock.receive(a[0],capacity:Int(a[1]))
            return .init(result:r.result,bytes:r.bytes)
        case .sleep:
            guard a == [500],q.bytes.isEmpty else { throw Boundary.malformed("client sleep") }
            Thread.sleep(forTimeInterval:0.5); return .init()
        case .message: throw Boundary.malformed("client window request")
        }
    }

    /// Socket requests inside the original notification, served exactly once
    /// per iteration permit. Its sleeps precede the next IO, not menu commit.
    public func answer(_ q: OriginalNetworkNotification.Request) throws -> OriginalNetworkNotification.Response {
        let a = q.arguments
        notificationRequestCount += 1
        switch q.kind {
        case .accept:
            guard a.count == 3,a[1] == 0,a[2] == 0,q.bytes.isEmpty else { throw Boundary.malformed("accept") }
            return .init(result:Int32(bitPattern:winsock.accept(a[0])))
        case .closeSocket:
            guard a.count == 1,q.bytes.isEmpty else { throw Boundary.malformed("notification closeSocket") }
            return .init(result:winsock.close(a[0]))
        case .send:
            guard a.count == 3,a[1] == q.bytes.count,a[2] == 0 else { throw Boundary.malformed("notification send") }
            return .init(result:winsock.send(a[0],q.bytes))
        case .receive:
            guard a.count == 3,a[1] == 77,a[2] == 0,q.bytes.isEmpty else { throw Boundary.malformed("notification receive") }
            let r = winsock.receive(a[0],capacity:Int(a[1]))
            return .init(result:r.result,bytes:r.bytes)
        case .sleep:
            guard a.count == 1,q.bytes.isEmpty else { throw Boundary.malformed("notification sleep") }
            Thread.sleep(forTimeInterval:Double(a[0])/1000)
            return .init()
        case .message,.windowDefault: throw Boundary.malformed("notification window request")
        }
    }

    /// Answers one main-menu Winsock request.
    public func answer(_ e: OriginalMainMenuEvent) throws -> OriginalMenuNetworkReply {
        requests.append(e)
        let w = e.arguments
        switch e.kind {
        case .startup:
            guard w.count == 1 else { throw Boundary.malformed("startup") }
            let (result, data) = winsock.startup(UInt16(truncatingIfNeeded: w[0]))
            return .init(result: result, word: UInt32(data[0]) | UInt32(data[1]) << 8)
        case .hostname:
            guard w.count == 1 else { throw Boundary.malformed("hostname") }
            let (result, name) = winsock.hostName(capacity: Int(w[0]))
            return .init(result: result, bytes: result == 0 ? Array(name.dropLast()) : [])
        case .hostLookup:
            guard e.strings.count == 1 else { throw Boundary.malformed("hostLookup") }
            guard let words = localAddresses ?? winsock.hostAddresses(e.strings[0]) else { return .init(word: 0) }
            return .init(word: Self.hostEntry, addresses: words.map { .init(word: $0, text: OriginalMacWinsock.text($0)) })
        case .socket:
            guard w.count == 3 else { throw Boundary.malformed("socket") }
            return .init(word: winsock.socket(family: Int32(bitPattern: w[0]), type: Int32(bitPattern: w[1]), protocol: Int32(bitPattern: w[2])))
        case .asyncSelect:
            guard w.count == 4 else { throw Boundary.malformed("asyncSelect") }
            return .init(result: winsock.asyncSelect(w[0], window: w[1], message: w[2], events: w[3]))
        case .bind:
            // sockaddr_in: family, port (network order), address word.
            guard w.count == 2, w[1] == 16, e.strings.count == 1, e.strings[0].count == 16 else { throw Boundary.malformed("bind") }
            let a = e.strings[0], port = UInt16(a[2]) << 8 | UInt16(a[3])
            let address = UInt32(a[4]) | UInt32(a[5]) << 8 | UInt32(a[6]) << 16 | UInt32(a[7]) << 24
            guard a[0] == 2, a[1] == 0 else { throw Boundary.malformed("bind family") }
            return .init(result: winsock.bind(w[0], address: address, port: port))
        case .listen:
            guard w.count == 2 else { throw Boundary.malformed("listen") }
            return .init(result: winsock.listen(w[0], backlog: Int32(bitPattern: w[1])))
        case .closeSocket:
            guard w.count == 1 else { throw Boundary.malformed("closeSocket") }
            return .init(result: winsock.close(w[0]))
        default: throw Boundary.malformed("\(e.kind)")
        }
    }
}
