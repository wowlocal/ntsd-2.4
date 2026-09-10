# Whole loading progress with the bundled library

`OriginalLibLoadingProgress` implements the complete4242e0 caller, including
animated rendering, installed424352/424357 label changes, library text, links,
overlay, presentation and the43d230 message-pump tail. All318 controlled calls
match complete globals and20727 ordered events. Six linked calls independently
retain timer, phase, click and library DC state. This is a controlled caller
comparison, not a full initialized loading chain or application/device test.

The earlier [initial loading](INITIAL_LOADING.md) and [menu loading](MENU_LOADING.md)
fixtures remain immutable pristine-EXE controls. Their fixed clocks select
the no-draw path. Neither those controls nor this new caller alone establishes
the library-enabled startup/catalog/asynchronous-worker connection.

## Reference and execution environment

The [finite plan](LIB_LOADING_PLAN.md) was written before capture. The source
producer [oracle_lib_loading.py](../../tools/oracle_lib_loading.py) uses pinned
NTSD2.4 EXE SHA256`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
bundled DLL SHA256`28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba`
and VC80 SHA256`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Unicorn2.1.4 executes the actual DLL installer at declared base36000000 after
76HIGHLOW relocations. The actual104 installer PCs produce13copies/62bytes,
two allocation requests4000/20000,26 protection and13 copy API requests.
Those Windows loader/API responses are declared research boundaries.

Whole loading calls execute the original bitmap/clip, fill, library text,
401a30 sound,4028a0 overlay/music,43e940 present, VC80 sprintf and43d230 bodies.
COM/GDI, clocks, Sleep, ShellExecute and message APIs supply declared numeric
responses. No link is opened, message sent or host device operated. The actual
DispatchMessage call is observed, but a Windows window procedure is not run.
No source function is replaced merely to suppress an inconvenient output path.

The declared three bitmap records contain full bytes and masks. The panel
bitmap and ordinary menu bitmap intentionally alias in these controls; the
null pointer and zero first-word paths are separate. This does not recover
the advertising worker's allocation/lifetime or claim original loaded pixels.
Both DLL allocations and the bitmap/resource storage remain unchanged.
Whole DLL images differ only at the retained DC word; Native owns that semantic
word rather than a DLL image or expected source pointer backing.

## Recovered caller behavior

If4511c0 is zero, the caller samples time and stores it. It samples time again
and compares unsigned wrapped elapsed time with33. At<=33 it samples once
more, computes signed wrapped`previous-now+33`, and requests Sleep only when
positive, capped at5ms. There is no rendering or message pump on that return.

For elapsed>33 it reads time again. If this new unsigned elapsed exceeds100,
it makes a fresh fourth clock request and uses`newTime-100`; otherwise it uses
the previous baseline. It stores baseline+33 before drawing the background.
The number and order of clock requests are preserved, including changing
results, wrapping counters and negative signed delay controls.

The source then increments4511bc with signed32 wrap and signed remainder10.
The installed jump stores that remainder and replaces the caller's filename
with the pinned DLL string `Loading files`. All three DLL strings contain the
same13 bytes; phase controls their COLORREF values:

| Remainder | COLORREF |
| --- | --- |
|signed<2, including negative remainders|00ffffff|
|5,6,7|00000099|
|all other remainders|000000ff|

Background argument is0, target is the live455608 surface, position is608/60.
The actual library text helper requests transparent SetBkMode1 and retains
DC only after a nonnegative GetDC result. The label never reads the original
caller string. At its actual309 entries SP is callerSP−16 and ESI is the
passed surface; no expected caller-stack word is imported into Native.

The two NOP bytes424357/424358 and the old label code424359..4243b0 are
bypassed by the installed jump. They remain in the immutable reference image;
their presence does not imply that the original filename/color branch executes.

## Links, output and message order

The caller tests458420 and the first word of the bitmap it references. A null
pointer or zero word skips the eight link slots. Otherwise, slots at4546f8
with100-byte stride are visited in order. A leading`?` skips a slot. Each
enabled slot writes458418, then draws frame`slot+2` from the live panel pointer.
Slot X is`1+198*(slot%4)` and Y is`142+194*(slot/4)`.

Hover tests are strict on left/top/bottom. The right bound is X+198, except
column3 accepts any larger X. Four white rectangle fills are requested in
top/bottom/left/right order. If held457580 is exactly1 and previous4511b8 is0,
the caller clears held first, requests401a30 confirmation sound, Sleep300, then
ShellExecute with operation`open` and the slot's live string. Numeric sound/
Shell results are ignored. The source can therefore clear the click before
later processing another slot; Native preserves these live reads.

Minimum enabled X/Y start at999; when both fall below999, frame12 is drawn
at(minX,minY−10). Frame14 is drawn at0/535 regardless of panel presence.
The bottom hover region is unsigned`mouseX-1<=145` and signedY>=535; it draws
frame13 and uses the same click/sound/Sleep order for the pinned URL
`http://www.littlefighter.com/advertise`. These are recorded requests only.

The caller copies current held into4511b8, draws the cursor with X capped at775
and signed wrappedY+2 capped at535, then executes4028a0 and43e940 in order.
The overlay shares existing volume/recording behavior with explicit library
text selection, so its later text calls update the same owned DC.

The original tail jumps to43d230 after restoring its stack. That helper requests
PeekMessage once. A nonzero result requests GetMessage; a nonzero GetMessage
result, including−1 in this declared control, requests TranslateMessage then
DispatchMessage. At most one message is processed. This does not model Windows
error handling beyond the observed branch or execution of the window callback.
The actual28-byte MSG storage lives at callerSP−28. No-draw calls skip this tail.

Fill's100-byte DDBLTFX input is captured at actual415160 entry. The helper
writes size and color, leaving92 bytes from earlier stack use. These retained
bytes are an explicit helper boundary in both source and Native; this study
does not recover their initialized application provenance or mark them defined.
The240 complete fill requests preserve all100 bytes and the separate mask.

## Comparison and remaining boundaries

| Evidence | Count |
| --- | ---: |
|Whole controlled returns|318|
|Animated label/message-pump calls / no-draw returns|309 /9|
|Compared globals bytes|14673792|
|Actual global stores / library DC stores|1303 /384|
|Ordered events / helper returns|20727 /5082|
|Bitmap requests / Blts / rectangle fills|1180 /1776 /240|
|Text GetDC requests / text outputs|391 /384|
|Clock requests / Sleep / Shell requests|640 /78 /73|
|Peek / Get / Translate / Dispatch requests|309 /23 /22 /22|
|Original EXE / DLL / CRT instruction starts|840 /80 /414|
|Retained calls / carries after the first|6 /5|

All253 reachable non-alignment caller starts execute. The straight-line
installed image inventory contains282 starts:28 belong to bypassed label/NOP
code and one is alignment4243ed. Both DLL bodies execute all76 static starts
plus four import thunks. This is not every branch outcome of every child or
the rest of the library. All whole returns preserve saved registers, SP1000f004,
CW023f/FPSW0/tagffff. This is source FPU history, not native process flags or
Windows/hardware equivalence.

[verify_lib_loading.py](../../tools/verify_lib_loading.py) independently checks
all513 blobs, full global/DC reconstruction, installed image bytes, retained
state, helper stack returns, fill backing/masks and exact message order.
The native API commits globals/DC after the whole call. Two native-only errors
after label output reject a missing bitmap and a late DispatchMessage callback;
both preserve all original input bytes and DC. External observer effects must
be buffered until the encompassing operation commits.

The initial source attempt treated458420 as a status-only word. Its first
enabled link reached43f010 and failed the declared bitmap-binding assertion.
After binding a real bitmap, the older read observer rejected4243d4's caller
read outside a draw helper. The completed fresh capture adds that observation
separately. Both terminal logs/source versions are retained. Neither was an
actual source memory fault, native discrepancy or reason to modify old expected
bytes. The source producer now retains atomic20-case incomplete checkpoints.

The verifier initially misidentified the installer's jump scratch; it now
reconstructs the actual final copy at DLL+309c and allocation words3092/3096.
Both failed verifier versions/logs remain. No source expected byte changed.

Raw4 release tests pass11.687s/build176.07s: loading318 in0.155s, library text
in0.080s and retained pristine menu presentation in11.452s. The native code and
comparisons passed on their first build. The532-file export starts atdb588b3
and overlays three owned native files, excluding unfinished transforms.

Publication adds one immutable fixture to207 unchanged prior pins,208 at
publication. Raw7085256bytes SHA256
`0a4c81b0c8cbfb89d40531a8f3fa155df77539080738ec1cebd9430182537ee9`;
packed1080643bytes SHA256
`55f41b902fbe76cdc7a46d0488578d0e487e81a280f4652a79bf3b1082c7139c`.
[Acceptance](../../tools/accept_lib_loading.py) verifies terminal logs and all
tested source/native pins before publication. [Artifact verification](../../tools/verify_lib_loading_artifacts.py)
checks full raw/packed bytes, JSON, SHA, all513 blobs and10 codec vendor files.
Fixture transport compression is separate from the game replay codec.

Final packaged6 release tests passed24.923s/build177.75s without raw overrides:
both retained initial-loading controls13.206s, loading318 in0.143s, library
text0.080s and pristine menu presentation11.494s. The533-file db588b3 export
contains the same three owned native files plus the new fixture; unfinished
concurrent transforms remain excluded. All owned source/SwiftPM jobs are
terminal. NTSDNative linked; no app window or device was exercised. Exact
handles, source hashes, exports, terminal failures and logs are retained in
`build/research/lib-loading-work.json`. Completed source output is not restarted
or overwritten. The full library-enabled initial loading, advertisement worker,
CRT/application join, remaining transform hook, actual Windows, app/device,
full match/content and clean-macOS goal remain open.

```sh
uv run tools/oracle_lib_loading.py
uv run tools/verify_lib_loading.py
swift test --package-path native -c release --filter 'Original(LibLoading|LibSurfaceText|MenuPresentation|InitialLoading)Tests'
python3 tools/verify_lib_loading_artifacts.py
```

Source reproduction requires a fresh output location/workspace; the producer
rejects an existing completed raw file. No original game file is changed.
