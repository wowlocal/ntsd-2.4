# Plan: standard macOS full screen for the game window

2026-10-01. User decision (2026-10-01): Alt+Enter as the original (done,
[APPLICATION_FULL_SCREEN](APPLICATION_FULL_SCREEN.md)); a standard macOS full
screen may be added separately. This is that addition. It is a Mac
presentation feature, not game behaviour: the game does not take part. The
original is not executed.

## Question

Let the player put the game's window into macOS full screen (the green
button, View → Enter Full Screen, ⌃⌘F) and back, with the 794×550 image
scaled to the screen with its aspect kept, while the game keeps running
exactly as in its window.

## What the game reads about its window

- WM_MOVE (43b3d0, case 3, windowed) stores GetClientRect and two
  ClientToScreen results at 453ccc. The app sends WM_SIZE/WM_MOVE only at
  creation.
- The display backend presents the desktop-sized primary by cropping it at
  the window's client rectangle on the desktop (`displayGeometry`, checked
  against the primary's screen).
- `clientRect`/`screenPoint` requests are answered from the live view.

macOS full screen resizes the content view to the screen, so each of these
would change, and the crop and the size checks would no longer describe the
794×550 client the game believes in.

## Design (declared Mac policy, not the EXE)

While the window is in macOS full screen, the window lease holds the
windowed geometry it had just before entering:

- `displayGeometry` returns the held geometry, so the primary's crop stays
  the game's client.
- `clientRect` returns the held client size; `screenPoint` adds the held
  client origin on the desktop.
- `display` accepts an image of the held client size, and the view draws it
  aspect-fit on black (as the Alt+Enter popup does).
- Mouse points map back through the fit.
- `snapshotPNG` returns the presented 794×550 frame.

No message is sent to the game on entry or exit, so 453ccc keeps its
windowed values. On exit the hold is released and everything follows the
window again.

- The window gets `.fullScreenPrimary`; observers of
  willEnterFullScreen/didExitFullScreen set and clear the hold through a
  backend method that the tests can call directly.
- The original-runtime app menu gains a View menu with the standard toggle
  (`toggleFullScreen:`, ⌃⌘F). That key equivalent goes to the menu before the
  game's key handling.
- A script command `fullscreen` toggles it for app checks.
- Alt+Enter inside macOS full screen is the game's own recreation. Its
  DestroyWindow closes the full-screen window, and the new window follows the
  game's own mode.

## Checks

- A window-backend test: hold, resize and move the window, then check
  `clientRect`, `screenPoint` and `displayGeometry` against the held values,
  `display` of the held size, the mouse mapping and the snapshot size. Then
  release, after which the live geometry returns.
- An app probe: `fullscreen` at the main menu, START and a click mapped
  through the fit, capture, `fullscreen` back, capture. No boundary.
- The window, display and runtime suites and the e2e set pass.

EXE envelope not recalculated.
