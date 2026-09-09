# Result table and replay indicators

`OriginalResultLayout` implements whole422218..422994 and its alternate422944
entry. It matches599 complete controlled original returns. One additional
malformed author input reaches an actual unmapped bitmap read in the original;
native rejects its unavailable bitmap backing and rolls back. This is **599
matches plus one source-fault rejection**, not600 successful matches.

The recorder's actual `OriginalResultRecording.Continuation` chooses the entry.
Result-table rendering is skipped when the recorder selects422944. The public
API retains the caller's own round result, an optional indicator target and
optional formatting storage. Missing values fail only when the source consumes
them. These controlled calls do not establish their earlier initialized lifetime.

## Game behavior

Eight seats prefer active primary slots0..<8 over fallback10..<18. The original
counts those seats, computes a45-pixel row span and centers the93-pixel base table
vertically within530 pixels; mode4 adds45 pixels. Header, rows, portraits and
footer preserve the real negative-picture behavior of43f010, including indexed
fallthrough and reads of supplied undefined bitmap backing. Device failures do
not terminate the table.

Each participant has a three-byte `P1 `..`P8 ` or `Com` label. The caller writes
the label before reading its signed glyph bytes, draws through the live team
font resources and advances X by9. This is a direct bitmap path, distinct from
the four-pass bitmap-font helper. Five signed Actor statistics are formatted
by actual VC80 `%d` in the source and drawn by whole401290 at the original
coordinates and colors. Mode1 consumes exactly-one rootSP64 defeat status;
other modes use signed winner/team/HP rules. Negative winners suppress the mark.

Mode4 draws four additional summary counters and its extra footer. Elapsed time
uses signed `(ticks + 15 wrapping)/30`, then minute/second or hour/minute/second
formatting with the original spaces and minimum two-digit fields. Every format
overwrites the same root44c destination. The known372-byte region ends before
the root5c0 security cookie; it is not a recovered C-array capacity. Native does
not create a fill pattern for missing caller backing.

Nonzero450b84 draws picture24 from45116c at(67,534), using the **retained rootSP68
destination**, rather than global455608. Nonzero44d030 then reads elapsed time
from the owned playback allocation+144 and invokes whole
[OriginalPlaybackInformation](PLAYBACK_INFORMATION.md). This retains mutable
author/info strings, actual four-pass NUL writes and recorded/current time order.
The public API resolves the playback pointer through live allocation ownership.

## Source environment and storage observations

[oracle_result_layout.py](../../tools/oracle_result_layout.py) executes the pinned
EXE and VC80 CRT on one Unicorn2.1.4 CPU at CW023f. Full controlled World,400Actors,
fourObject headers,17bitmaps, globals, playback and caller backing are declared
inputs. Memory and register hooks recover format/label writes, original helper
order, retained reads and the fault boundary needed for the native macOS port.
Only COM/GDI/PTD responses are supplied boundaries. No bitmap, text, formatting,
clipping or playback-info helper is replaced by an expected result.

All537 decoded caller starts execute:515 table and22 indicator instructions.
This is instruction-start coverage, not proof of every branch outcome. The
complete600-input inventory contains1103EXE and424CRT instruction addresses.
The599 normal calls produce386781 ordered events,25661Blts,66705 helper returns,
9877 actual formats,9589GDI text calls and42140 caller-format byte writes. There
are288 separately verified complete REP copies in the playback child and420
undefined bitmap read events. The source verifies DF0, counts, ECX0, ESI/EDI
advancement, copied bytes and write masks for those REP copies.

The source records every low-local store and preserves full before/after bytes.
Native compares their order and reconstructed bytes, normalizing only root50's
known `10-(World+4)` pointer adjustment to the logical displacement10. The
root4c top coordinate is stored at4222ce after six pushes; it is not a write to
root64. The source records155 actual422673 stage reads and156 actual42294d target
reads. Both retained words are otherwise unchanged. Complete World/Actor/Object,
bitmap and playback records remain unchanged; globals and formatting storage
are compared with their exact write masks.

The malformed127-byte author case initially stopped at the harness's bitmap
binding assertion. The source process was confirmed terminal. A continuation
retained the580 atomically captured cases byte-for-byte, then explicitly allowed
that declared corrupted pointer to reach its real unmapped read, without mapping
invented backing. Author storage beginning44fd18 overwrites44fd8c with41414141;
43f04b reads its count at4141414d and faults. Native's bitmap resolver rejects the
same unavailable binding after the same observed prefix and restores globals and
caller storage. Corrupted descriptor backing is not an accepted native domain.

## Verification

[accept_result_layout.py](../../tools/accept_result_layout.py) independently checks
complete raw bytes, SHA and every blob; reconstructs globals and both caller
regions from actual writes; verifies bitmap values/masks, formats, ABI returns,
REP records and caller coverage. No original expected result was edited to make
the native comparison pass.

The initial six-case comparison passes0.024s, including four rollback trials.
The first149.02s release build succeeded and linked NTSDNative, but its test
invocation used a relative corpus path that resolved inside native/ and failed
to open the file. The corrected invocation used an absolute preserved snapshot.
The complete599-match/one-rejection test passes2.195s after a34.31s test rebuild.
Late failure at the playback time overlay's third font pass follows the entire
table,22formats, author/info writes and two earlier time passes; both globals
and caller storage roll back. Separate trials reject missing formatter backing,
stage result and indicator target only at their actual consumption points.
External rendering events must remain buffered until the enclosing tick commits.

Raw corpus:57182095bytes, SHA256
`46b4e7cd5466fc38a2035de4a19a3905981e0efd20ce1370d774c702f028d863`.
Acceptance passes2.239s/build155.60s before publication. The packed fixture has
7989824bytes and571 inner blobs; all182 previous fixture pins remain unchanged,
with183 current. [verify_result_layout_artifacts.py](../../tools/verify_result_layout_artifacts.py)
independently verifies full raw/packed byte identity, complete JSON, every SHA and
length, all571 blobs and ten unchanged vendor hashes. Both fresh initialized
continuations are now accepted in [GAMEPLAY_RESULT_LAYOUT](GAMEPLAY_RESULT_LAYOUT.md),
bringing the pin set to186 including the independently accepted output fixture.
Packaged regression after adding the optional own-reference continuation passes
all3release tests in44.722s/build157.73s, without raw overrides: this controlled
corpus2.098s and both retained initialized result-recording chains42.624s.
Their full513221records/842185012bytes and1605FPU checkpoints remain unchanged.
The earlier stack audit remains in [RESULT_LAYOUT_PLAN](RESULT_LAYOUT_PLAN.md).
Actual whole422994 output order, enabled own sound,422ab8/ret4, app-window,
multiple ticks/full match, Windows/device and clean-Mac checks remain open.
