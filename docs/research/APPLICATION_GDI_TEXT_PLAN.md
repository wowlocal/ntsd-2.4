# Plan: GDI text in the app

2026-10-01. Parent: [match end](APPLICATION_MATCH_END.md) (the District
milestone's open caveat: Summary numbers and names are blank), [text
responses](APPLICATION_TEXT_RESPONSES.md) (the Core reply contract). The
original is not executed.

## Question

Draw the original's GDI text in the app: the Summary numbers, names, the
start-menu values (Background, Difficulty, …), "Loading files" and the other
strings the Core already sends as GetDC/TextOut requests. The app currently
answers every GetDC with E_FAIL, so no text appears.

## Contract (recovered)

Two text routines draw strings onto a DirectDraw surface:

- **lib.dll 10001298..10001309**, installed over 401290 (`OriginalLibSurfaceText`):
  GetDC(surface), SetBkMode(dc, TRANSPARENT), SetTextColor(dc, color),
  TextOutA(dc, x, y, text, length), ReleaseDC(surface, dc).
- **The EXE's own 401290** (`OriginalSurfaceText`): GetDC, SetBkColor(dc,
  background), SetTextColor, TextOutA, ReleaseDC. The DC keeps its default
  background mode OPAQUE.

Numeric GDI results are ignored by both; only GetDC's HRESULT is returned.
Neither the EXE nor lib.dll imports CreateFont*, CreateFontIndirect* or
GetStockObject (import tables checked). SelectObject is used only for bitmap
loading. So the font is the DirectDraw surface DC's default, the stock
SYSTEM_FONT, with the default text alignment TA_TOP|TA_LEFT: (x, y) is the
top-left of the character cell. In OPAQUE mode TextOutA fills the text
extent (advance width × cell height) with the background colour.

## Obstacle and declared deviation (temporary, user decision 2026-10-01)

SYSTEM_FONT is a raster font that ships with Windows. It is not in the game's
distribution or on macOS, and it cannot be redistributed. The user's decision
is to use the standard macOS system font for GDI text, keeping position,
size, colour and alignment as close to the original as possible. The font
difference is recorded as a temporary deviation and does not block further
work.

The Windows system font at 96 DPI has a 16 px cell, ascent 13, internal
leading 3 (em 13 px) and bold weight. The app will draw:

- the macOS system font, bold, at 13 px (the em), baseline at y + 13;
- not antialiased: GDI draws raster fonts without smoothing, and surfaces may
  later be blitted with a colour key, which smoothing would break;
- the exact SetTextColor COLORREF (0x00BBGGRR) as the surface's XRGB value,
  under the existing native XRGB policy for fills;
- in OPAQUE mode, the extent box (advance width × 16) in the SetBkColor
  colour first;
- clipped to the surface.

String bytes are decoded as ASCII. A byte ≥ 0x80 is a boundary until the
strings are surveyed and a code page is declared.

## Implementation

1. `OriginalMacDisplayBackend`: a text DC per acquired surface (GetDC
   returns DD_OK and a declared DC handle; one DC at a time). SetBkMode,
   SetBkColor and SetTextColor return the previous value, starting from
   OPAQUE, white and black. TextOutA renders as above and returns TRUE;
   ReleaseDC returns DD_OK. While a text DC is held, Blt to that surface is a
   boundary.
2. The front menu answers GetDC through the backend instead of E_FAIL.
3. Loaded menus and gameplay give the Core `dcResult` 0 and the declared DC.
   The committed text events (getDC … releaseDC) replay on the display in
   order, like blits and fills.
4. The Demo music residue (4025d0's ECX) came from lib.dll's GetDC failure.
   With a successful GetDC the routine's last call is ReleaseDC, whose ECX is
   equally unknown. The declared placeholder value stays, marked temporary
   (user decision).

## Checks

- Unit tests of the backend's DC state, results, colours, OPAQUE box,
  clipping and the ASCII boundary.
- The app shows the Summary numbers and names, the start-menu values and the
  loading text (captures as evidence).
- The e2e references change only in captures that contain text. They are
  re-recorded after inspecting the new captures, and the change is recorded.

EXE envelope not recalculated.
