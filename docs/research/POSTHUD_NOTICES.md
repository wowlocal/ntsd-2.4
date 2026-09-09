# Diagnostic and command-key notices after HUD

`OriginalPostHUDNotices` implements the entire421a2d..421cdc caller, using
native diagnostic formatting,401290 text,415160 fill and43f010/43ef70 bitmap
mechanisms. The controlled source executes the actual EXE and actual VC80
sprintf on the same CPU. The EXE SHA is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
DLL SHA is
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

The comparison deliberately distinguishes819 direct source/native matches,
8 signaling-NaN oracle discrepancies and4 oversized strings that corrupt the
original caller's cookie. The NaN cases are compared separately to independently
executed quiet-NaN companions, as explained below. They are NOT included in the
819 direct matches. No original result is replaced to obtain a green comparison.

This is the controlled implementation of step1 in
[TICK_TAIL_PLAN](TICK_TAIL_PLAN.md). Both initialized chains from
[GAMEPLAY_HUD](GAMEPLAY_HUD.md) now continue through421cdc in
[GAMEPLAY_NOTICES](GAMEPLAY_NOTICES.md), with public native composition and no
source-local import. That own disabled-notice path does not replace the enabled
controlled branches verified here. This milestone does not extend the app or prove
a complete tick, match, Windows output or hardware floating-point exceptions.

## Caller behavior and storage

Entry EDI is0, retained from the whole HUD/command path. The caller compares
global450bec against it and loads actualsprintf intoESI even when diagnostics
are disabled. When450bec is nonzero, it follows World slot0 regardless of its
activity. Actor+14 is read as signed32; Actor+60 then+48 pass through FLDQ/FSTPQ
into the compound `%2.3f %2.4f %d` arguments, with+48 displayed first. Native
uses [DIAGNOSTIC_NUMBERS](DIAGNOSTIC_NUMBERS.md), including its original
17-digit conversion and second fixed-precision rounding. No host printf is used.

The next line prints all eight bytes44d040..47 as signed integers. The third
uses the low byte4553e8 as `%c`, followed by signed450bfc as `%d`. The source
sign-extends the character argument, but `%c` emits its low byte. A zero byte
is part of sprintf's full output and count;401290 sees only the prefix before
that NUL. The source capture records both representations, including bytes
behind the embedded terminator. Text positions are(0,0),(0,30),(0,60), foreground
ffffff and background0, on global455608.

All five formats write at rootSP+48c. The exit URL uses rootSP+46c. The retained
local region46c..<5c0 contains340 bytes;5c0 is the security cookie established
by the actual41bc90 prologue and checked by422aa7..422ab0. Thus308 bytes remain
from the formatting destination to the cookie. This is a known storage extent,
NOT proof of a308-byte C array. The source checks complete local bytes and
write masks after every sprintf and at421cdc. Unwritten bytes survive later
shorter strings and URL writes; native preserves this backing and its masks.

Four separate controls produce322,323,312 and631 output bytes before the NUL.
They actually overwrite the cookie while still reaching421cdc. They do not run
the later cookie check or prove a full return/crash outcome. Native reports an
explicit unsupported cookie-overwrite error and preserves the caller's local
state. It neither truncates the string nor silently supplies a larger buffer.
The corresponding source outputs and cookie writes remain in the fixture.

## Notices and rendering

450c2c==1 takes precedence over the key-notice selector. It draws the original
exit instruction at(610,110) in7d7d7d, copies29 literal bytes from449204, then
decodes each byte by subtracting its index modulo4. The repeated source strlen
loops observe the current bytes. The resulting28-byte URL is
`http://www.LittleFighter.com`, drawn at(5,110) inc8c8c8. This is original game
text; it does not initiate a network request. The last operation draws resource
global44f8f8 at(360,288), picture−1,key1,mirror0. SourceESI ends28 andEDI ends
rootSP+489, not the original sprintf/zero pair. Subsequent consumers must not
assume those entry registers survive.

Otherwise450c28==1 formats the four signed counts450c18/1c/20/24 using the
original function-key literal. Mode451160==1 first fills(0,128)..(794,149) with0,
then draws the text at(0,129); other modes draw at(0,109) without a fill.
450c28==2 draws the locked literal at(0,109); other values produce no notice.
Diagnostics still precede either notice branch.

401290 executes through GetDC/GDI/ReleaseDC responses. A negative GetDC result
skips all five following GDI/release events; later errors do not suppress other
messages. The fill's100-byte DDBLTFX writes only its size and color. Its92 other
bytes come from the actual helper-entry stack backing, which can have been
written by the preceding CRT invocation. This remains a declared input to the
native fill, not a claim that native reconstructs every CRT stack byte.

The bitmap uses the already recovered negative-picture fallthrough, complete
metadata read masks, clipping and COM requests. Neither count−1 nor negative
viewport dimensions are sanitized. There are192 undefined bitmap reads in the
controlled corpus. Resources are synthetic declared records; no Windows pixel
or heap-initialization provenance follows from them.

The public API only commits caller strings after successful completion. A late
bitmap-resolution failure after both exit texts verifies rollback of all local
writes. World, Actors and globals are read-only. Device callbacks must still
be buffered until the enclosing tick commits; already-issued external drawing
cannot be rolled back by this API.

## Signaling NaN: keep the oracle discrepancy visible

Unicorn2.1.4 retains signaling-NaN bits through the original FLDQ/FSTPQ pair
and leaves its observed status word unchanged. Consequently the actual source
sprintf in that harness receives an SNaN and emits the old CRT SNaN spelling.
This is a limitation of the execution witness, not sufficient evidence for
Windows hardware behavior.

Intel documents FLD m64fp's SNaN invalid-operand exception and the conversion
of a masked signaling NaN to a quiet NaN by setting the most-significant fraction
bit. The operation is the same in64-bit and non64-bit modes. See
[Intel SDM, Vol.1 §4.8.3.5/Table4-7 and Vol.2A FLD/3-412](https://cdrdv2-public.intel.com/843820/325462-sdm-vol-1-2abcd-3abcd-4-1.pdf),
PDF pages104/1004. Downloaded manual SHA256:
`6f6286056edad4ffdca8716e9039e9598e9e71ab029284facde6a786e1b65f73`.

`tools/probe_x87_load_store.c` executes the same x87 operand types on24 signed
binary64 controls. Locally this is an x86_64 process through **Rosetta**, explicitly
reported by sysctl.proc_translated; it is not a Windows or physical-x86 run.
It preserves ordinary/quiet values, quiets all four signaling inputs, reports
IE1 for those inputs andDE2 for subnormals. Unicorn's status behavior differs
as well. The probe can be rebuilt on physical x86 for independent follow-up.

Native quiets a NaN before handing its binary64 bits to the original numeric
formatter. For each of the8 differing caller cases, the test retains the
unaltered source output, asserts that native differs from it, and compares the
entire native rendering/local-storage sequence to a separately executed source
case with the corresponding quiet-NaN operand. This verifies composition after
the architectural load conversion; it is not direct whole-caller equivalence
for signaling NaNs. Actual Windows FPU/status verification remains open.
The native API here implements operand bytes, not process-wide exception flags.
This finding also limits earlier source-only NaN/exception evidence: it must
not be promoted to hardware equivalence without an independent check. Earlier
finite corpora and all their accepted fixtures remain unchanged.

## Corpus and coverage

| Controlled group | Calls |
| --- | ---: |
|Diagnostic/exit/key/mode gates|180|
|All256 signed-byte/character values|256|
|Coordinates, rounding boundaries and NaN classes|108|
|Slot0 aliases and inactive Actors|9|
|Signed function-key counts and modes|80|
|GetDC and later device results|120|
|Bitmap count/viewport/undefined backing|72|
|Long strings inside known local backing|2|
|Total comparison cases|827|
|Separate cookie-overwrite cases|4|

All827 compare424,408 World/Actor bytes and masks,46,144 globals bytes,340 local
bytes and masks, and all19,802 events. The8 NaN rendering/local comparisons use
the explicit companion contract above; their World/Actor/globals comparisons
still use their own original cases. The ordered events contain2,061 formats,
2,375 text requests/GetDC calls,2,167 each background/color/length/textOut/release,
69 fills,157 bitmap requests,1,400 metadata reads,290 clips and240 Blts.
4,952 helper returns verify stack cleanup and saved registers.

The PC union across all831 source calls contains2,190 actual instruction starts:
485 EXE and1,705 DLL. COM/GDI responses, hooked_getptd78132e29 and the stopped
421cdc are excluded. The union includes the cookie-overwrite controls.

| Function/range | Executed / static instruction starts |
| --- | ---: |
|421a2d..421cdc caller|195/198|
|401290 text|46/46|
|415160 fill|28/28|
|43ef70 clip|45/57|
|43f010 bitmap|171/214|

The three missing caller instructions handle a negative index remainder in the
URL loop. That index starts0 and reaches28; the arm is unreachable with the
original constant literal. Missing clipping and mirrored-bitmap paths remain
outside this caller's coordinates and mirror0. Counts are instruction starts,
not every branch outcome or complete-game proof.

## Reproduction and acceptance

```sh
uv run --script tools/oracle_posthud_notices.py
xcrun clang -arch x86_64 -O0 -Wall -Wextra tools/probe_x87_load_store.c -o build/research/probe-x87-load-store
arch -x86_64 build/research/probe-x87-load-store > build/research/posthud-x87-load-store.json
curl -L --fail https://cdrdv2-public.intel.com/843820/325462-sdm-vol-1-2abcd-3abcd-4-1.pdf -o build/research/intel-sdm-dec24.pdf
python3 tools/accept_posthud_notices.py
swift test --package-path native -c release --filter 'OriginalPostHUDNoticesTests|OriginalDiagnosticNumberTests'
```

SwiftPM runs sequentially; do not edit source/fixtures during a build. Acceptance
checks all169 previous fixture hashes, source/CRT/literal identity, full
case/event/helper/instruction inventories, precise NaN-discrepancy pairs and
the separate x87 witness. It runs native comparisons before publishing the
lossless fixture. [Evidence](../evidence/posthud-notices.json) records the
separate direct/companion/overflow scopes and pins the artifacts.

Raw acceptance passed3 release XCTest in1.453s after a137.25s build,
including the retained74,424 diagnostic-number comparisons. Final packaged
verification passed the same3 tests in1.422s after a138.96s build, without
an external raw-corpus override. NTSDNative linked; no app window was opened.

The first compile needed an inner `try` in the signed-byte closure. The first
executable test exposed ambiguous labels for signed midpoint inputs. The producer
labels were clarified, and4 identical input dictionaries were deduplicated before
a fresh capture; no old fixture or expected result was changed. No numeric or
rendering rule was adjusted to force a comparison to pass.

The raw corpus is7,304,998 bytes; its lossless fixture is233,963 bytes. An
independent check verified full inflated byte/JSON equality, lengths and SHA256.
All169 previous fixture hashes remain unchanged among170 current pins in
build/research/posthud-notices-fixture-pins.json. Artifact and625 local-link
checks are retained inposthud-notices-artifact-verification.json and
posthud-notices-link-verification.json. Python compilation and diff checks
passed. Source, C-probe and SwiftPM processes were terminal before commit.

Both complete pinned GAMEPLAY_HUD parents have now been freshly reproduced on
their original CPUs/stacks and joined to the public native continuation in
[GAMEPLAY_NOTICES](GAMEPLAY_NOTICES.md). Unknown caller backing/FPU differences
remain explicit. Next continue [result ownership/43dd60](RESULT_RECORDING_PLAN.md), result layout, bitmap labels,
presentation, enabled queued sound and actual422ab8/ret4. App integration,
continuous original-DAT sequences, the first completed Naruto/Sasuke District
match and the full-game goal remain open.
