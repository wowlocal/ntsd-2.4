import Foundation

/// Retains one loading ticket and services its ordered audio only after the
/// entire Host/Core preparation unwinds. Non-audio inputs remain declared.
public final class OriginalApplicationObservedLoadingAudio<Platform: OriginalApplicationStartupPlatform> {
    public typealias Host = OriginalApplicationHostSession<Platform>
    public typealias Exchange = OriginalLoadingAudioExchange
    public enum Boundary: Error, Equatable { case reentrantAttempt, missingLoading, staleLoading }
    public enum Outcome { case request(Exchange.Permit), prepared(Host.LoadedOutcome) }
    private let host: Host, sequence: UInt64, entry: Host.Session.PendingLoading
    private let exchange = Exchange(), lock = NSRecursiveLock(), domain: OriginalWaveRegionDomain
    private var inFlight = false
    public init(host: Host,domain: OriginalWaveRegionDomain) throws {
        guard let entry = host.pendingLoading else { throw Boundary.missingLoading }
        self.host = host;self.entry = entry;sequence = host.committedSequence;self.domain = domain
    }
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock();defer { lock.unlock() };return try body()
    }
    private func attempt<T>(_ body: () throws -> T) throws -> T {
        try locked {
            guard !inFlight else { throw Boundary.reentrantAttempt }
            inFlight = true;defer { inFlight = false };return try body()
        }
    }
    public var exchangeSnapshot: Exchange.Snapshot { locked { exchange.snapshot } }
    public func resume(
        prepare: (Host.LoadingContext,Platform,OriginalLoadingAudioContext) throws -> Host.LoadedOutcome,
        beforePrepared: (Host.LoadedOutcome,Platform) throws -> Void = { _,_ in }) throws -> Outcome {
        try attempt {
            let audio = try OriginalLoadingAudioContext(domain:domain,cursor:exchange.snapshot.cursor())
            do {
                let outcome = try host.prepareLoadedUntilBoundary(prepare:{ context,platform in
                    // Both checks run inside the Host attempt lock; another
                    // committed iteration cannot race this validation.
                    guard self.host.committedSequence == self.sequence,
                        context.entry.isSameAttempt(as:self.entry) else { throw Boundary.staleLoading }
                    return try prepare(context,platform,audio)
                },beforePrepared:{ outcome,platform in
                    try beforePrepared(outcome,platform)
                    // Host publication after this hook is nonthrowing.
                    _ = try self.exchange.finish(audio.cursor)
                })
                return .prepared(outcome)
            } catch let needed as Exchange.RequestNeeded {
                return .request(try exchange.claim(needed))
            }
        }
    }
    public func beginService(_ permit: Exchange.Permit) throws { try attempt { try exchange.beginService(permit) } }
    public func answer(_ permit: Exchange.Permit,response: Exchange.Response,
        retaining resources: [any OriginalApplicationStartupResource] = []) throws {
        try attempt { try exchange.answer(permit,response:response,retaining:resources) }
    }
    public func fail(_ permit: Exchange.Permit,diagnostic: String,
        retaining resources: [any OriginalApplicationStartupResource] = []) throws {
        try attempt { try exchange.fail(permit,diagnostic:diagnostic,retaining:resources) }
    }
    public func cancel() throws { try attempt { exchange.cancel() } }
}
