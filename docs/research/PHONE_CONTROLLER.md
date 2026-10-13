# The user's phone controller on iOS and Android

Requested by the user on 2026-10-13 with a photo: "вот джойстик для мобильных
телефонов (погугли что за девайс). если у нас есть поддержка таких джойстиков
то супер. Погугли мануалы и примеры реализаций. Если нет, то добавь. и в ios
и в android".

## The device

**Razer Kishi V2** (USB-C, the Android model), as it reports itself when
plugged into a Pixel 10 (C2, 2026-10-13): "Razer Razer Kishi V2", USB vendor
0x1532, product 0x0712. C0 took the photo for a Backbone One (USB-C), which
has the same layout (clip-on, telescoping bridge, Xbox-layout A/B/X/Y, two
sticks, bumpers and triggers, a logo button); that identification was wrong.

What Android sees (C2, [evidence](../evidence/phone-controller-c2-20261013.json)):

- HID interface 0: the gamepad — sticks X/Y and Z/RZ and triggers GAS/BRAKE
  (0–255, rest 0x80, flat 15), the d-pad as hat axes HAT0X/HAT0Y (−1…1),
  15 buttons (A/B/X/Y, bumpers, triggers, Select, Start, the Razer button,
  stick clicks). Android: one input device, sources KEYBOARD | GAMEPAD |
  JOYSTICK, controller number 1.
- HID interface 2: the same 15 buttons with no axes — a second input device,
  sources KEYBOARD | GAMEPAD, controller number 0. It sent nothing during
  the played test.
- HID interface 1: a multi-touch surface (2048×4096, 5 slots), plus a
  consumer-control node (volume, power, menu, back, home keys) and an
  ABS_MISC node.

## What the port already does

- iPad, Apple TV and macOS: `OriginalGameControllerJoysticks` (TVOS_WEB T1b)
  takes the first two extended GameController gamepads connected at launch
  (the original probes its joysticks once, at startup), samples them every
  25 ms as joySetCapture asks, maps the left stick or the d-pad to the WinMM
  X/Y axes and A/B/X/Y to buttons 1–4. Whether iOS/macOS accept this Android
  model as an extended gamepad is not observed (Razer sells a separate
  iPhone model).
- Android: `NTSDAndroidGamepads` (TVOS_WEB T1c) takes the first two input
  devices whose sources include SOURCE_GAMEPAD at launch, the d-pad from hat
  axes or d-pad keys over the left stick, A/B/X/Y (or BUTTON_1–4) as buttons
  1–4; a gamepad's B never becomes Back (Esc). The Kishi V2 works there
  (C2: the user played a match with it, "все работает").

## Gaps

1. ~~The iPhone is not a target~~ — C1 added the separate iPhone build.
2. **The second, empty gamepad node** (C2): the Android host takes the
   first two input devices with SOURCE_GAMEPAD, so with the Kishi V2 alone
   the game is also given its button-only interface-2 node as joystick 2 — a
   joystick that never moves or presses, and a second player's gamepad
   connected alongside would not get that slot (inference from the probe
   code and the device list; the game's joystick count is not logged on
   Android). C3.
3. Not observed: the Kishi V2 on the Mac and on iOS (GameController).
4. Menu, Options, Capture and the Razer button have no role in the
   original's joystick (four buttons). Left as they are unless the user wants
   a host shortcut (e.g. Menu as Esc).
5. Recorded, not studied: closing the third run logged a SIGSEGV in ART's
   "Jit thread pool" thread 94 ms after the window went invisible, then
   Zygote reported the process "exited cleanly (0)" (no tombstone, no
   dialog; the first two runs closed without it). The host's onDestroy calls
   `exit(0)` while ART's threads are still running.

## Plan

| ID | Step | Status |
| --- | --- | --- |
| C0 | This card: identify the device, the sources, the survey | **done** |
| C1 | iPhone: a **separate iPhone build** (user, 2026-10-13: "сделай iPhone отдельную сборку") — its own harness platform and bundle id, iPhone only, landscape, the shared full-screen view and safe areas; scenarios on an iPhone simulator equal with frames identical (CoreText group), the controller path unchanged | **done** |
| C2 | The controller observed: on a Pixel 10 with adb over Wi-Fi (`dumpsys input`, `getevent`, logcat) while the user played; on the Mac (macOS app, iPhone/iPad simulators) | **Android done**; the Mac part needs the controller plugged into the Mac |
| C3 | The Android host skips a gamepad node without joystick axes when a node with axes has the same vendor and product (the Kishi V2's interface 2), so one controller is one joystick and a second gamepad gets joystick 2 | next |

## Next task

C3: in `NTSDAndroidGamepads.probe`, read each SOURCE_GAMEPAD device's vendor
and product ids (InputDevice.getVendorId/getProductId) and drop a node
without SOURCE_JOYSTICK when a node with it has the same ids; keep the order
and the two-device limit otherwise. Gates: the Android build, the emulator's
vs scenario equal with frames identical, an independent read-only review of
the host change, then the Pixel with the Kishi V2 (the found devices are not
logged, so a host log line or the user's check that the game offers one
joystick). The Mac part of C2 waits for the controller on the Mac.
Recorded from C1's review: the game's Alt+Enter popup fills the iPhone's
screen edge to edge, so the Dynamic Island and the rounded corners cover its
edges (the windowed picture is clear of them); an empty launch screen may flash
white in light mode.

## Ledger

| Date | Step | Result | Evidence | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-13 | C0 | The device is most likely a Backbone One (USB-C); both hosts already map extended/HID gamepads; the iPhone is the missing iOS target | this card | — |
| 2026-10-13 | C1: the separate iPhone build | `ios_app.py --platform iphone` / `ios_device.py --iphone`: its own app (`local.ntsd.native.iphone`, iPhone only, landscape). The first run stopped every scenario at the menu's first blit: the game was told the iPhone's 874×402-point screen, smaller than its window; the iOS host now scales the told screen up to at least 800×600 as Android does (iPad and TV unchanged), fits the original window on screens smaller than the frame and defers the bottom-edge gesture on phones. iPhone 17 Pro: all 10 scenarios equal, 18,088 frames identical to the CoreText reference; iPad vs equal and identical; landscape screenshots on two iPhones (the picture full height, the Dynamic Island in a side bar) | [evidence](../evidence/phone-controller-c1-20261013.json) | this commit |
| 2026-10-13 | C2 (Android) | The controller is a **Razer Kishi V2** (USB 1532:0712), not a Backbone One. On a Pixel 10 (Android 17) the user played with it ("все работает"): one gamepad node with sticks, triggers and the d-pad as hat axes, plus a button-only gamepad node (interface 2) that sent nothing and that the host takes as joystick 2; closing the run logged an ART JIT-thread SIGSEGV during `exit(0)`, the process still exited 0 | [evidence](../evidence/phone-controller-c2-20261013.json) | this commit |
