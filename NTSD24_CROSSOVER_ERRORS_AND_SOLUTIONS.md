# NTSD 2.4 on CrossOver: Errors and Solutions

Date: March 31, 2026

## Goal

Run `NTSD 2.4` reliably in CrossOver with the original game feel, and identify the real cause behind the `chars/flash.dat` load crash.

## Environment

- Host: macOS
- Compatibility layer: CrossOver / Wine (32-bit bottle)
- Working bottle: `NTSD24XP` (Windows XP mode)
- Main executable: `NTSD 2.4.exe`

## Primary Error Signatures

### 1) Crash near `chars/flash.dat`

Observed at startup/load:

- In-game symptom: crash reported while loading `chars/flash.dat`
- Wine debugger symptom:
  - `Unhandled exception: page fault on read access to 0x0000000c in 32-bit code (0x0043f04b)`
  - Faulting instruction:
    - `ntsd 2.4+0x3f04b: cmpl %edi, 0xc(%esi)`
  - Register state shows `esi=0`, so this is a null dereference inside game code.

Interpretation:

- `flash.dat` is the visible checkpoint where loading appears to fail, but the crash is from invalid runtime state in the EXE path (null object access), not a direct file-open failure.

### 2) Wine media pipeline warnings

Repeated warnings in failing runs:

- `GStreamer-CRITICAL ... gst_element_set_state: assertion 'GST_IS_ELEMENT (element)' failed`
- `fixme:quartz:... Unsupported subtype ...`

Interpretation:

- Wine media stack compatibility is imperfect for this title/build (WMA/DirectShow path in particular), and may contribute to unstable startup in some runs.

### 3) Missing extensionless resource lookups

Trace showed repeated failed opens for names like:

- `PAUSE`, `DEMO`, `SCORE_BOARD1..4`, `CHARMENU`, `CM1..CM5`, `CMA`, `CMA2`, `CMC`, `RFACE`, `SPARK`, `MENU_BACK9`

Interpretation:

- These appear to be optional/custom resource probes. They are likely not fatal by themselves, but they happen in the same late-load region before the crash in failing runs.

## What Was Tested (and Results)

### A) DAT decryption/cleanup and `flash.dat` sanitation

Actions:

- Decrypted DATs for analysis
- Rebuilt/cleaned `chars/flash.dat`
- Removed extreme out-of-range numeric literals in several `itr` fields

Result:

- Crash signature at `0x0043f04b` remained in failing setup.

Conclusion:

- Helpful for data hygiene, but not sufficient as a universal fix for this environment.

### B) VC++ runtime installation

Action:

- Installed Microsoft `vcredist_x86` (VC++ 2005 SP1) into bottle.

Result:

- No direct elimination of `0x0043f04b` crash in failing path.

Conclusion:

- Runtime dependency alone is not the root fix here.

### C) Sound-name overflow mitigation

Background:

- LF2-derived engines have a known sound-name buffer limitation (19-char names + fixed table behavior).
- Overlong names can corrupt adjacent memory in some builds/mod states.

Actions:

- Added tool: `tools/fix_ntsd_sound_names.py`
- Applied to decrypted tree:
  - `275` overlong references remapped
  - `27` DAT files updated

Result:

- Good hardening step for modified/decrypted trees.
- Did not fully remove crash in the specific failing run path.

Conclusion:

- Valid known risk and worthwhile fix for unstable/edited trees, but not the only factor.

### D) Media path tests (WMA to WAV, BGM toggles)

Actions:

- Temporarily disabled BGM folder
- Converted BGM `.wma` to `.wav` and patched EXE string references in a test path

Result:

- Behavior changed between runs, but not a definitive universal fix for all modified trees.

Conclusion:

- Media path is a compatibility risk area, but final stable result came from using a clean distribution path/bottle state.

### E) Clean build verification

Action:

- Ran pristine extraction:
  - `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a`
- In bottle:
  - `NTSD24XP`

Result:

- This is the confirmed working setup.

Conclusion:

- Root practical fix: use clean `2.4_2.0a` content in a clean/stable XP bottle launch path.

## Final Recommended Solution

Use exactly:

- Bottle: `NTSD24XP`
- Game directory: `downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a`
- EXE: `NTSD 2.4.exe`

Avoid for normal play:

- Experimental edited tree:
  - `downloads/NTSD_2.4_2.0a/NTSD 2.4_2.0a`
  - (contains multiple troubleshooting modifications)

## One-Command Launcher

Use script:

- `./run-ntsd24.sh`

It launches the known-good clean path in bottle `NTSD24XP`.

## Useful References

- PlayOnLinux LF2 dependency notes (`vcrun2005`, `wmp9`, `quartz`, `devenum`):  
  https://www.playonlinux.com/en/app-2623-Little_Fighter_2_v20a.html
- LF-Empire thread discussing LF2/NTSD sound-name limit behavior and memory corruption risk:  
  https://lf-empire.de/forum/showthread.php?tid=10014

