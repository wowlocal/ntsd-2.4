import Foundation

/// FIPS 180-4 SHA-256 for hosts without CryptoKit. Core uses SHA-256 only to
/// check packaged-input integrity; Apple builds keep CryptoKit, and a macOS
/// test requires this digest to equal CryptoKit's on every packaged input.
public enum PortableSHA256 {
    public static func hash<D: DataProtocol>(data: D) -> [UInt8] {
        var hasher = Hasher()
        for region in data.regions { region.withUnsafeBytes { hasher.update($0) } }
        return hasher.finalize()
    }

    struct Hasher {
        private var state: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                                       0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
        private var pending: [UInt8] = []
        private var length: UInt64 = 0

        mutating func update(_ bytes: UnsafeRawBufferPointer) {
            guard let base = bytes.baseAddress, bytes.count > 0 else { return }
            length &+= UInt64(bytes.count)
            var offset = 0
            if !pending.isEmpty {
                let take = min(64 - pending.count, bytes.count)
                pending.append(contentsOf: UnsafeRawBufferPointer(start: base, count: take))
                offset = take
                guard pending.count == 64 else { return }
                let block = pending
                block.withUnsafeBytes { compress($0.baseAddress!) }
                pending.removeAll(keepingCapacity: true)
            }
            while bytes.count - offset >= 64 { compress(base + offset); offset += 64 }
            if offset < bytes.count {
                pending.append(contentsOf: UnsafeRawBufferPointer(start: base + offset, count: bytes.count - offset))
            }
        }

        mutating func finalize() -> [UInt8] {
            let bits = length &* 8
            var tail: [UInt8] = [0x80]
            tail.append(contentsOf: repeatElement(0, count: (55 &- (pending.count % 64) + 64) % 64))
            for shift in stride(from: 56, through: 0, by: -8) { tail.append(UInt8(truncatingIfNeeded: bits >> UInt64(shift))) }
            let savedLength = length
            tail.withUnsafeBytes { update($0) }
            precondition(pending.isEmpty, "SHA-256 padding must end on a block boundary")
            length = savedLength
            var digest: [UInt8] = []
            digest.reserveCapacity(32)
            for word in state { for shift in stride(from: 24, through: 0, by: -8) { digest.append(UInt8(truncatingIfNeeded: word >> UInt32(shift))) } }
            return digest
        }

        private mutating func compress(_ block: UnsafeRawPointer) {
            var next = state
            withUnsafeTemporaryAllocation(of: UInt32.self, capacity: 64) { w in
                for t in 0..<16 { w[t] = UInt32(bigEndian: block.loadUnaligned(fromByteOffset: t * 4, as: UInt32.self)) }
                for t in 16..<64 {
                    let s0 = Self.rotr(w[t - 15], 7) ^ Self.rotr(w[t - 15], 18) ^ (w[t - 15] >> 3)
                    let s1 = Self.rotr(w[t - 2], 17) ^ Self.rotr(w[t - 2], 19) ^ (w[t - 2] >> 10)
                    w[t] = w[t - 16] &+ s0 &+ w[t - 7] &+ s1
                }
                var a = next[0], b = next[1], c = next[2], d = next[3]
                var e = next[4], f = next[5], g = next[6], h = next[7]
                for t in 0..<64 {
                    let t1 = h &+ (Self.rotr(e, 6) ^ Self.rotr(e, 11) ^ Self.rotr(e, 25)) &+ ((e & f) ^ (~e & g)) &+ PortableSHA256.k[t] &+ w[t]
                    let t2 = (Self.rotr(a, 2) ^ Self.rotr(a, 13) ^ Self.rotr(a, 22)) &+ ((a & b) ^ (a & c) ^ (b & c))
                    h = g; g = f; f = e; e = d &+ t1
                    d = c; c = b; b = a; a = t1 &+ t2
                }
                next[0] &+= a; next[1] &+= b; next[2] &+= c; next[3] &+= d
                next[4] &+= e; next[5] &+= f; next[6] &+= g; next[7] &+= h
            }
            state = next
        }

        @inline(__always) private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 { (x >> n) | (x << (32 - n)) }
    }

    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]
}

#if !canImport(CryptoKit)
/// The subset of CryptoKit's `SHA256` that the package uses: `hash(data:)`
/// returning a byte sequence.
public enum SHA256 {
    public static func hash<D: DataProtocol>(data: D) -> [UInt8] { PortableSHA256.hash(data: data) }
}
#endif
