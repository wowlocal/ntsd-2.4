import Foundation

/// Touch as the mouse, for hosts without a pointer (iPad, Android). The
/// original's menus act on the item under the cursor and read the left button
/// across game ticks, as a player's click holds it (the scripted clicks hold
/// it for 10-15 loop iterations too). A tap delivers down and up at once, so
/// here a touch first moves the cursor, presses after `hover` seconds and keeps
/// the button down for at least `hold` seconds after the press.
@MainActor public final class OriginalRuntimeTouchMouse {
    /// Sends one mouse message: (message, client x, client y, buttons).
    let send: (UInt32,Int32,Int32,UInt32) -> Void
    public var hover: TimeInterval = 0.08, hold: TimeInterval = 0.15
    private var generation = 0, pressed = false, released = false
    private var pressedAt = Date.distantPast, last: (Int32,Int32) = (0,0)
    public init(send: @escaping (UInt32,Int32,Int32,UInt32) -> Void) { self.send = send }

    public func began(x: Int32,y: Int32) {
        if pressed { pressed = false; send(0x202,last.0,last.1,0) }   // a release still pending from the last touch
        generation += 1; released = false; last = (x,y)
        send(0x200,x,y,0)
        let g = generation
        DispatchQueue.main.asyncAfter(deadline:.now()+hover) { [weak self] in MainActor.assumeIsolated { self?.press(g) } }
    }
    public func moved(x: Int32,y: Int32) { last = (x,y); send(0x200,x,y,pressed ? 1 : 0) }
    public func ended(x: Int32,y: Int32) {
        last = (x,y); released = true
        if pressed { release(generation) }   // otherwise the pending press releases after its hold
    }
    private func press(_ g: Int) {
        guard g == generation,!pressed else { return }
        pressed = true; pressedAt = Date(); send(0x201,last.0,last.1,1)
        if released { release(g) }
    }
    private func release(_ g: Int) {
        let wait = max(0,hold-Date().timeIntervalSince(pressedAt))
        DispatchQueue.main.asyncAfter(deadline:.now()+wait) { [weak self] in
            MainActor.assumeIsolated {
                guard let self,g == self.generation,self.pressed else { return }
                self.pressed = false; self.send(0x202,self.last.0,self.last.1,0)
            }
        }
    }
}
