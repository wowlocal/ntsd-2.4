# Original startup data package and Native input ownership

The regular startup package and Native input ownership are verified in the
finite scope below. App startup, window and device acceptance remain open.

The finite plan is in `build/research/application-startup-inputs-native-20260912/`.
This card supplies the accepted [Core bootstrap](APPLICATION_BOOTSTRAP.md) from
ordinary bundled data, toward a standalone native application. The complete game
and its window, input, audio, content, networking and Windows/clean-Mac criteria
remain unchanged.

## Reference and input boundary

The only reference is the pinned original NTSD distribution. Its EXE SHA-256 is
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Current operations read static PE data/resources and saved comparison records;
no original EXE/DLL is executed, no producer imported, no historical capture or
auditor rerun. Static resource extraction imports the inspected PE reader and
`import_ntsd` constants/read_bytes; it does not invoke its import_game function
or function-local replay helper. Source faults and all three safety incidents
retain their previous separate status.

The regular package contains 45 payload files plus one pinned manifest:

- `initial.bin` and `initial.mask`: the 50,088-byte range at 44d000, entirely
  inside original PE .data. It has 8,192 file-backed bytes and 41,896 bytes of
  section zero-fill. All mask bytes are one. The 46,144 initial global bytes,
  2,132 outer bytes and 1,812 trailing World bytes reproduce the independently
  verified initial regions, never an after-state.
- Seven unchanged original files: 15-byte adinfo, 179-byte control and five menu
  WAVs. Baseline ad0 is absent, distinct from an empty file or an unknown path.
  Only the existing baseline control CRLF-to-LF projection is established:
  nine CRLF pairs yield 170 bytes. Adinfo is retained raw.
- 36 complete RT_BITMAP DIB resources / 28,986,014 bytes, with original resource
  names, language 1028 and exact raw file spans. Twenty-three have uncompressed
  24-bit headers; thirteen are 8-bit RLE. This card parses their BITMAP metadata;
  it does not decode RLE pixels or establish a renderer.

Every payload, the exact manifest bytes, file set and modes compare independently
against the baseline and [saved input inventory](../../build/research/application-startup-inputs-native-20260912/input-inventory1.json).
The 46 files total 29,700,372 bytes; payloads total 29,685,082 bytes. The compiled
manifest digest binds the versioned Native reader to this exact input package.
No executable, reference corpus, saved after-state, synthetic handle or response
tape belongs to it. The file-backed district3.bmp occurs only in the separate
narrow bitmap regression and is not an additional startup resource here.

## Production ownership and actual join

`OriginalApplicationStartupInputs` loads and validates regular files before a
Core attempt, then owns immutable bytes and parsed bitmap metadata. Filesystem
changes after the snapshot cannot change its inputs. A declared file overlay
creates another value, with absence and empty contents represented separately.
The finite original names are explicit; no arbitrary path/case or filesystem
error semantics are inferred.

The bootstrap comparator uses this producer for all 48 primary attempts and
all parents consumed by the retained 50 MenuInput chains and 12 LoadingPrefix
cases. Initial globals, adinfo and five WAV bytes are supplied by the package.
All 19 selected settings inputs are reconstructed from the packaged raw/logical
control and explicit source producer formulas: ten baseline logical, one raw
CRLF and eight modified inputs. Saved `sc.input` and initial blobs are used only
for comparison. The normal nested original-entry has info/content/defaults panel
children and no panel bitmap invocation; this card does not newly verify that
unreached device branch.

`OriginalApplicationBitmapInputs` binds the handle returned by a declared image
request to a packaged DIB. It supplies GetObject's fields from that metadata and
GetSurfaceDesc's fields from the actual preceding Native CreateSurface request.
The test strips all captured structure writes from the response packets passed
to this route. The original full request/reply projection still compares every
resulting operation independently.

Image and surface bindings are value-owned, staged with the whole menu iteration
and retained in Session.State. Rollback and the pending-loading bridge preserve
them. They record modeled platform provenance separately from wrapper ownership.
Positive CreateSurface can produce a token/descriptor while the recovered loader
continues only on exact zero. A successful DeleteObject marks its input image
unavailable; a failed deletion retains it. Release results remain recorded
requests, not proof of actual Windows/device destruction. Missing/deleted input
owners, negative CreateSurface with an out token and captured structure writes
are typed rejections. Successful GetObject/description with suppressed writes
are outside this selected contract; pointer-output absence and result-based
write omission remain separate.

## Validation and distribution gates

The frozen release selection contains the prior 24 Bootstrap/WinMain/Bitmap/
Settings/Front/Body/MenuReturn/MenuInput/MessageLoop/LoadingPrefix methods and
four new input-package methods. New checks cover exact input provenance, value
snapshots after files disappear, absent-versus-empty overlays, missing/corrupt/
unexpected files and bitmap response ownership/rejection.

`package_assets.py`, called by the existing native app build, installs the same
ordinary package at Contents/Resources/OriginalStartup. The reader checks that
app resource location; an app with a missing package throws instead of falling
back to SwiftPM resources. Command-line/test clients use the module package.
A separate placement
check reproduced all 46 file bytes/modes at that app layout. This is a package
placement check, not an executed app, window or device claim.

The independent inventory and package verifier preserve all 370 historical
fixtures. An initial syntax error in the new package verifier was retained; the
corrected read-only verifier changes no baseline, package or reference bytes.
All 28 selected bundled release methods passed in 173.944s; the build took
295.28s. This includes all 48 primary attempts (47 menu commits and the
separate NULL-cursor rejection), 50 retained MenuInput chains, 12 LoadingPrefix
cases, six startup and 17 first-menu late controls, the retained nine MenuReturn
late controls and four new package methods. The new complete image/surface maps
compare raw DIB bytes, deletion flags, all Native-created descriptor bytes/masks
and ordered Release results. Relocated app loading and missing app resources
are exercised through Foundation Bundle; no executable app is launched.

Candidate1 built in 308.06s and ran all 28 methods in 151.300s with one unexpected
failure in the new relocated-snapshot test. Foundation supplied its argument via
`/var` and enumerated children via `/private/var`; deriving relative names from
different spellings broke exact package composition. The saved second diagnostic
reconstructs the actual argument and proves that normalizing both URLs yields
the exact 46 manifest names. Candidate3 applies that correction without weakening
the file set or symlink checks. Baseline, package, expected bytes and masks stay
unchanged. The first path diagnostic and first verifier syntax error are retained.

Candidate2 was frozen with independent review fixes before the final Native1
failure was inspected, and was never executed. Its files and manifest remain.
Candidate3 also includes the complete bitmap-map comparator, negative
CreateSurface/output rejection and strict app-bundle lookup from that review.
All three frozen candidates are preserved; Native1 and Native3 are terminal.

All 370 historical fixtures and all 871 current Native files compare bytewise.
The Native archive contains 871
members / 4045280185 payload bytes.
The evidence archive contains 312
members / 607206935 payload bytes,
including all 91 plan pins, changed versions of all three frozen Native candidates,
packagers, diagnostics, input/package reviews and saved comparison corpora.
Git marks package files `-text` to preserve exact endings; only the two raw
control/adinfo inputs use binary diffs because their original CRLF and trailing
spaces must remain. The manifest and source stay reviewable.
Every archive member's bytes, SHA and mode were verified. Changed plan inputs
retain their pinned base versions. Shipping resources remain regular local files;
development archives and isolated builds reside in the verified X5 task area.

[Machine-readable acceptance](../evidence/application-startup-inputs.json) records
the exact inputs, results and archive hashes. Final publication review and staged
Git verification are separate post-archive records required before commit.
NTSDNative linked; the original, a window and hardware devices were not executed.

## Open continuations

The extra 18 LoadingPrefix sound names remain separate retained regression inputs,
not silently included among the five menu WAVs. Full startup/loading asset coverage,
live user-file persistence and general Windows CRT text mode remain open, as do
AppKit queue/key/mouse/clock, raster/audio delivery, workers/reentrancy, earlier
PE/CRT/NLS/private capability backing, full own catalog/loading return, War43a860,
complete match/game and Windows/clean-Mac acceptance. No current test substitutes
for those required end-to-end results.
