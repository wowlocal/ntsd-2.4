import Foundation
import NTSDCore

enum Result: Int32 {
    case ok = 0, argument, version, handle, bounds, undefined
    case unsupported = 6
    case limit = 7, internalError
}

private struct Session {
    enum Payload { case actor(OriginalStateRecord), loaded(LoadedSession) }
    var payload: Payload
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
    case LoadedSessionError.input: return Result.argument.rawValue
    case LoadedSessionError.lifecycle, LoadedSessionError.deliberateRollback, LoadedSessionError.continuation:
        return Result.unsupported.rawValue
    default: return Result.internalError.rawValue
    }
}

@_cdecl("ntsd_bridge_abi_version")
public func bridgeABIVersion() -> UInt32 { 1 }

@_cdecl("ntsd_bridge_capabilities")
public func bridgeCapabilities() -> UInt32 { 3 } // Actor storage + pristine front/settings; no gameplay.

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
            sessions[handle] = Session(payload: .actor(actor))
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
        switch session.payload {
        case .actor: lifecycle.pointee = 1
        case .loaded(let loaded): lifecycle.pointee = loaded.lifecycle
        }
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
        guard case .actor(let actor) = session.payload else { return Result.unsupported.rawValue }
        for i in 0..<actorSize {
            bytes[i] = actor.bytes[i]
            defined[i] = actor.defined[i] ? 1 : 0
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
        guard case .actor(let actor) = session.payload else { return Result.unsupported.rawValue }
        do {
            let answer = try actor.integer(at: Int(offset), as: Int32.self)
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
        guard case .actor(var actor) = staged.payload else { return Result.unsupported.rawValue }
        guard staged.revision < UInt64.max else { return Result.limit.rawValue }
        do {
            for i in 0..<Int(count) {
                guard offsets[i] % 4 == 0 else { return Result.argument.rawValue }
                // Read first: a setup edit cannot declare unknown backing known.
                _ = try actor.integer(at: Int(offsets[i]), as: Int32.self)
                try actor.write(values[i], at: Int(offsets[i]))
            }
            staged.payload = .actor(actor)
            staged.revision += 1
            sessions[handle] = staged
            return Result.ok.rawValue
        } catch { return result(error) }
    }
}

@_cdecl("ntsd_bridge_create_pristine")
public func bridgeCreatePristine(_ abi: UInt32, _ root: UnsafePointer<UInt8>?, _ count: UInt32,
                                 _ profile: UInt32, _ output: UnsafeMutablePointer<UInt64>?) -> Int32 {
    guard abi == 1 else { return Result.version.rawValue }
    guard count > 0, count <= 4096, let root, let output, let profile = LoadedPlatformProfile(rawValue: profile),
          let path = String(bytes: UnsafeBufferPointer(start: root, count: Int(count)), encoding: .utf8),
          path.hasPrefix("/"), !path.utf8.contains(0) else { return Result.argument.rawValue }
    return locked {
        let loadedCount = sessions.values.reduce(0) { count, session in
            if case .loaded = session.payload { return count + 1 }; return count
        }
        guard sessions.count < 64, loadedCount < 4, nextHandle < UInt64.max else { return Result.limit.rawValue }
        do {
            let loaded = try LoadedSession(root: path, profile: profile)
            let handle = nextHandle
            sessions[handle] = Session(payload: .loaded(loaded)); nextHandle += 1
            output.pointee = handle
            return Result.ok.rawValue
        } catch { return result(error) }
    }
}

private func loadFrontSettings(_ handle: UInt64, failBeforeCommit: Bool) -> Int32 {
    locked {
        guard var session = sessions[handle] else { return Result.handle.rawValue }
        guard case .loaded(var loaded) = session.payload else { return Result.unsupported.rawValue }
        guard session.revision < UInt64.max else { return Result.limit.rawValue }
        do {
            try loaded.loadFrontSettings(failBeforeCommit: failBeforeCommit)
            session.payload = .loaded(loaded); session.revision += 1
            sessions[handle] = session
            return Result.ok.rawValue
        } catch { return result(error) }
    }
}

@_cdecl("ntsd_bridge_load_front_settings")
public func bridgeLoadFrontSettings(_ handle: UInt64) -> Int32 {
    loadFrontSettings(handle, failBeforeCommit: false)
}

/// Explicit developer observer failure after real nested loading, before commit.
@_cdecl("ntsd_bridge_developer_front_rollback")
public func bridgeDeveloperFrontRollback(_ handle: UInt64) -> Int32 {
    loadFrontSettings(handle, failBeforeCommit: true)
}

/// Query size with bytes=nil/capacity=0. Revision accompanies each successful
/// query/copy; no state can be imported through this observation-only API.
@_cdecl("ntsd_bridge_loaded_snapshot")
public func bridgeLoadedSnapshot(_ handle: UInt64, _ bytes: UnsafeMutablePointer<UInt8>?, _ capacity: UInt32,
                                _ size: UnsafeMutablePointer<UInt32>?, _ revision: UnsafeMutablePointer<UInt64>?) -> Int32 {
    guard let size, let revision, (bytes == nil && capacity == 0) || bytes != nil else { return Result.argument.rawValue }
    return locked {
        guard let session = sessions[handle] else { return Result.handle.rawValue }
        guard case .loaded(let loaded) = session.payload else { return Result.unsupported.rawValue }
        do {
            let data = try loaded.snapshot(revision: session.revision)
            guard data.count <= 32_000_000 else { return Result.limit.rawValue }
            if let bytes {
                guard Int(capacity) >= data.count else { return Result.bounds.rawValue }
                data.copyBytes(to: bytes, count: data.count)
            }
            size.pointee = UInt32(data.count); revision.pointee = session.revision
            return Result.ok.rawValue
        } catch { return result(error) }
    }
}
