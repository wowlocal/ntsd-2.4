# The user's phone controller on iOS and Android

Requested by the user on 2026-10-13 with a photo: "вот джойстик для мобильных
телефонов (погугли что за девайс). если у нас есть поддержка таких джойстиков
то супер. Погугли мануалы и примеры реализаций. Если нет, то добавь. и в ios
и в android".

## The device

A clip-on USB-C controller with a telescoping bridge: left module with a
capture (screenshot) button, d-pad, options (…) button and left stick; right
module with menu (≡), a logo button, Xbox-layout A/B/X/Y (Y top), right stick,
an LED by B; bumpers and triggers on the top edge. This matches the
**Backbone One (USB-C)** — Android and iPhone 15 and later; the first and
second generations share the layout. Model and generation to be confirmed
when it is connected (vendor 0x358a).

What the sources say:

- Buttons: A, B, X, Y, LB/RB, LT/RT, clickable sticks (L3/R3), d-pad,
  Backbone, Menu, Capture, Options
  ([EFTM review](https://eftm.com/2024/05/backbone-one-second-gen-review-an-excellent-update-to-a-mobile-gaming-essential-246343),
  [JB Hi-Fi listing](https://jbhifi.co.nz/products/backbone-one-mobile-gaming-controller-usb-c-2nd-gen)).
- Android: Android 8.0 or later; the button map cannot be changed; the
  Backbone button opens the Backbone app (single press back to the game,
  double press the shortcuts menu)
  ([Backbone help: Android](https://help.backbone.com/hc/en-us/categories/13753251866647-Backbone-One-for-Android),
  [button map](https://help.backbone.com/hc/en-us/articles/13754191941655-Can-I-adjust-the-button-map-on-Backbone-One-for-Android)).
- iOS: an MFi controller, so GameController reports it as an extended
  gamepad named "Backbone One"; SDL enables its guide (Backbone) button,
  which iOS delivers on a long press (> 400 ms), and leaves its share button
  masked
  ([SDL patch](https://discourse.libsdl.org/t/sdl-added-support-for-the-backbone-one-guide-button/35660)).
  The PlayStation Edition reports vendor 0x358a, products 0x0104 and 0x0304
  (second generation)
  ([SDL](https://discourse.libsdl.org/t/sdl-added-support-for-the-backbone-one-playstation-edition-ea710/42730),
  [SDL](https://discourse.libsdl.org/t/sdl-add-second-gen-backbone-one-to-recognized-controllers-8ba90/66689)).

## What the port already does

- iPad, Apple TV and macOS: `OriginalGameControllerJoysticks` (TVOS_WEB T1b)
  takes the first two extended GameController gamepads connected at launch
  (the original probes its joysticks once, at startup), samples them every
  25 ms as joySetCapture asks, maps the left stick or the d-pad to the WinMM
  X/Y axes and A/B/X/Y to buttons 1–4. A Backbone One is an extended
  gamepad, so it is covered there.
- Android: `NTSDAndroidGamepads` (TVOS_WEB T1c) takes the first two input
  devices whose sources include SOURCE_GAMEPAD at launch, the d-pad from hat
  axes or d-pad keys over the left stick, A/B/X/Y (or BUTTON_1–4) as buttons
  1–4; a gamepad's B never becomes Back (Esc). A USB HID gamepad such as the
  Backbone One is covered if Android lists it with SOURCE_GAMEPAD.

## Gaps

1. **The iPhone is not a target.** The iOS app is built for the iPad only
   (`UIDeviceFamily` [2] in `ios_app.py` and `ios_device.py`), and this
   controller is for phones. Add the iPhone: device family, landscape only,
   the shared full-screen view (WINDOW_SCALING S1/S5) on a 19.5:9 screen
   (bars at the sides, the Dynamic Island inside them), scenarios on an
   iPhone simulator.
2. **Not seen on the device yet.** Whether Android lists it as SOURCE_GAMEPAD,
   whether its d-pad comes as hat axes or keys, the stick ranges, and what
   GameController reports on iOS/macOS — to be observed with the controller
   connected.
3. Menu, Options, Capture and the Backbone button have no role in the
   original's joystick (four buttons); Capture and Backbone are the system's
   and the Backbone app's on Android. Left as they are unless the user wants
   a host shortcut (e.g. Menu as Esc).

## Plan

| ID | Step | Status |
| --- | --- | --- |
| C0 | This card: identify the device, the sources, the survey | **done** |
| C1 | iPhone: a **separate iPhone build** (user, 2026-10-13: "сделай iPhone отдельную сборку") — its own harness platform and bundle id, iPhone only, landscape, the shared full-screen view and safe areas; scenarios on an iPhone simulator equal with frames identical (CoreText group), the controller path unchanged | **done** |
| C2 | The controller observed: plugged into the Mac (macOS app and the iPhone/iPad simulators get it through GameController) and into the A12 (adb over Wi-Fi while it holds the USB-C port: `dumpsys input`, `getevent`, the game's joystick events and a played match) | needs the user to plug it in |
| C3 | Fix what C2 shows (mapping, d-pad source, detection) on each host | queued |

## Next task

C2 needs the controller: plug it into the Mac (the macOS app and the iPhone/iPad
simulators then see it through GameController: its name, extended-gamepad
elements, the d-pad and sticks in a played match), then into the A12 with adb
over Wi-Fi (`adb tcpip 5555`, `adb connect` while the phone is on USB, then the
controller in the port): `dumpsys input` (vendor 0x358a, sources), `getevent`,
the game's joystick count at start and a played match. The controllers are probed once, at launch
(as the original does), so the phone must already sit in the controller when
the game starts. A real iPhone needs a development profile covering
`local.ntsd.native.iphone` (`ios_device.py --iphone` checks it before building).
Recorded from C1's review: the game's Alt+Enter popup fills the iPhone's
screen edge to edge, so the Dynamic Island and the rounded corners cover its
edges (the windowed picture is clear of them); an empty launch screen may flash
white in light mode.

## Ledger

| Date | Step | Result | Evidence | Commit |
| --- | --- | --- | --- | --- |
| 2026-10-13 | C0 | The device is most likely a Backbone One (USB-C); both hosts already map extended/HID gamepads; the iPhone is the missing iOS target | this card | — |
| 2026-10-13 | C1: the separate iPhone build | `ios_app.py --platform iphone` / `ios_device.py --iphone`: its own app (`local.ntsd.native.iphone`, iPhone only, landscape). The first run stopped every scenario at the menu's first blit: the game was told the iPhone's 874×402-point screen, smaller than its window; the iOS host now scales the told screen up to at least 800×600 as Android does (iPad and TV unchanged), fits the original window on screens smaller than the frame and defers the bottom-edge gesture on phones. iPhone 17 Pro: all 10 scenarios equal, 18,088 frames identical to the CoreText reference; iPad vs equal and identical; landscape screenshots on two iPhones (the picture full height, the Dynamic Island in a side bar) | [evidence](../evidence/phone-controller-c1-20261013.json) | this commit |
