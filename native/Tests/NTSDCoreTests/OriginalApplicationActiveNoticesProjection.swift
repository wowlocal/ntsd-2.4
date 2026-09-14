import XCTest
@testable import NTSDCore
@testable import NTSDReferenceChecks

/// Finite current-input branch specification; never calls the production notice routine.
/// A selected notice is an open extension, not permission to suppress its output.
enum OriginalApplicationActiveNoticesProjection {
    typealias P = OriginalApplicationGameplayStateProjection
    static func requireNoOutput(_ globals: OriginalStateRecord) throws {
        try P.require(globals.bytes.count == 0xb440,"Notices complete globals extent")
        func word(_ address: Int) throws -> Int32 {
            try globals.integer(at:address-0x44d000,as:Int32.self)
        }
        try P.require(word(0x450bec) == 0,"Active diagnostic branch needs comparison")
        try P.require(word(0x450c2c) != 1,"Active exit notice needs comparison")
        let selector = try word(0x450c28)
        try P.require(selector != 1 && selector != 2,"Active function-key notice needs comparison")
        // No mode, Actor, resource, or caller-local read follows these branches.
    }
}
