// Held key presses for the cross-play trial: the original reads WM_KEYDOWN/KEYUP
// into per-frame key state, so an instant down/up (cua-driver press_key) is lost.
// usage: keyhold <pid> <pid|hid> <holdMs> <gapMs> <keycode>...
// "pid" posts to the game process only; "hid" posts to the HID tap and refuses
// unless the game is the frontmost application before every event.
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 6, let pid = pid_t(args[1]), let hold = UInt32(args[3]), let gap = UInt32(args[4]) else {
    print("usage: keyhold <pid> <pid|hid> <holdMs> <gapMs> <keycode>..."); exit(2)
}
let mode = args[2]
let codes = args[5...].compactMap { CGKeyCode($0) }
let source = CGEventSource(stateID: .hidSystemState)

func front() -> Bool { NSWorkspace.shared.frontmostApplication?.processIdentifier == pid }

func post(_ code: CGKeyCode, _ down: Bool) {
    guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return }
    if mode == "pid" {
        event.postToPid(pid)
    } else {
        guard front() else { print("refused: game is not frontmost"); exit(3) }
        event.post(tap: .cghidEventTap)
    }
}

for code in codes {
    post(code, true); usleep(hold * 1000)
    post(code, false); usleep(gap * 1000)
    print("key", code, "held", hold, "ms")
}
