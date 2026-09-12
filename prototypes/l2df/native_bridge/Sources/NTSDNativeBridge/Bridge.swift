import Foundation
import NTSDCore

private enum Result: Int32 {
    case ok = 0, argument, version, handle, bounds, undefined
    case limit = 7, internalError
}

private struct Session {
    var actor: OriginalStateRecord
    var revision: UInt64 = 0
}

// Registry IDs have no relationship to Swift/native/original object addresses.
// All registry and session access, including output copies, holds this lock.
private let registryLock = NSLock()
private var sessions: [UInt64: Session] = [:]
private var nextHandle: UInt64 = 1
private let actorSize = OriginalStateRecord.actorSize

private func locked(_ operation: () -> Int32) -> Int32 {
    registryLock.lock()
    defer { registryLock.unlock() }
    return operation()
}

private func result(_ error: Error) -> Int32 {
    switch error {
    case OriginalStateError.outOfBounds: return Result.bounds.rawValue
    case OriginalStateError.undefinedBytes: return Result.undefined.rawValue
    default: return Result.internalError.rawValue
    }
}

@_cdecl("ntsd_bridge_abi_version")
public func bridgeABIVersion() -> UInt32 { 1 }

@_cdecl("ntsd_bridge_capabilities")
public func bridgeCapabilities() -> UInt32 { 1 }

@_cdecl("ntsd_bridge_live_sessions")
public func bridgeLiveSessions() -> UInt32 {
    registryLock.lock()
    defer { registryLock.unlock() }
    return UInt32(sessions.count)
}

@_cdecl("ntsd_bridge_create")
public func bridgeCreate(_ abi: UInt32, _ backing: UnsafePointer<UInt8>?, _ count: UInt32,
                         _ output: UnsafeMutablePointer<UInt64>?) -> Int32 {
    guard abi == 1 else { return Result.version.rawValue }
    guard count == UInt32(actorSize), let backing, let output else { return Result.argument.rawValue }
    return locked {
        guard sessions.count < 64, nextHandle < UInt64.max else { return Result.limit.rawValue }
        do {
            let actor = try OriginalStateRecord.actor(over: Array(UnsafeBufferPointer(start: backing, count: actorSize)))
            let handle = nextHandle
            sessions[handle] = Session(actor: actor)
            nextHandle += 1
            output.pointee = handle
            return Result.ok.rawValue
        } catch { return result(error) }
    }
}

@_cdecl("ntsd_bridge_destroy")
public func bridgeDestroy(_ handle: UInt64) -> Int32 {
    locked {
        guard sessions.removeValue(forKey: handle) != nil else { return Result.handle.rawValue }
        return Result.ok.rawValue
    }
}

@_cdecl("ntsd_bridge_info")
public func bridgeInfo(_ handle: UInt64, _ lifecycle: UnsafeMutablePointer<UInt32>?,
                       _ revision: UnsafeMutablePointer<UInt64>?) -> Int32 {
    guard let lifecycle, let revision else { return Result.argument.rawValue }
    return locked {
        guard let session = sessions[handle] else { return Result.handle.rawValue }
        lifecycle.pointee = 1 // ACTOR_STORAGE; no match owner exists.
        revision.pointee = session.revision
        return Result.ok.rawValue
    }
}

@_cdecl("ntsd_bridge_snapshot")
public func bridgeSnapshot(_ handle: UInt64, _ bytes: UnsafeMutablePointer<UInt8>?,
                           _ defined: UnsafeMutablePointer<UInt8>?, _ capacity: UInt32,
                           _ revision: UnsafeMutablePointer<UInt64>?) -> Int32 {
    guard capacity >= UInt32(actorSize), let bytes, let defined, let revision else { return Result.argument.rawValue }
    return locked {
        guard let session = sessions[handle] else { return Result.handle.rawValue }
        for i in 0..<actorSize {
            bytes[i] = session.actor.bytes[i]
            defined[i] = session.actor.defined[i] ? 1 : 0
        }
        revision.pointee = session.revision
        return Result.ok.rawValue
    }
}

@_cdecl("ntsd_bridge_read_i32")
public func bridgeReadI32(_ handle: UInt64, _ offset: UInt32,
                         _ value: UnsafeMutablePointer<Int32>?) -> Int32 {
    guard let value, offset % 4 == 0 else { return Result.argument.rawValue }
    return locked {
        guard let session = sessions[handle] else { return Result.handle.rawValue }
        do {
            let answer = try session.actor.integer(at: Int(offset), as: Int32.self)
            value.pointee = answer
            return Result.ok.rawValue
        } catch { return result(error) }
    }
}

@_cdecl("ntsd_bridge_setup_apply_i32")
public func bridgeSetupApplyI32(_ handle: UInt64, _ offsets: UnsafePointer<UInt32>?,
                                   _ values: UnsafePointer<Int32>?, _ count: UInt32) -> Int32 {
    guard count > 0, count <= 64, let offsets, let values else { return Result.argument.rawValue }
    return locked {
        guard var staged = sessions[handle] else { return Result.handle.rawValue }
        guard staged.revision < UInt64.max else { return Result.limit.rawValue }
        do {
            for i in 0..<Int(count) {
                guard offsets[i] % 4 == 0 else { return Result.argument.rawValue }
                // Read first: a setup edit cannot declare unknown backing known.
                _ = try staged.actor.integer(at: Int(offsets[i]), as: Int32.self)
                try staged.actor.write(values[i], at: Int(offsets[i]))
            }
            staged.revision += 1
            sessions[handle] = staged
            return Result.ok.rawValue
        } catch { return result(error) }
    }
}
