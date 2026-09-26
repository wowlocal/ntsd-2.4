# Windows cursor bitmap probe preparation

2026-09-26, base ab504f5. [Plan](WINDOWS_CURSOR_BITMAP_PROBE_PLAN.md),
[publication and exact pins](../evidence/windows-cursor-bitmap-probe.json).
This prepares a bounded Windows observation for the first native menu. The original
11×19 LF2_CURSOR RLE8 resource has 108 written and 101 unwritten positions;
macOS ImageIO also differs at three written pixels. No missing pixel is filled by
this preparation, and no Windows or original-game execution has occurred here.

## Prepared observation

Freestanding x86 and ARM64 collectors each have 19 static KERNEL32 imports, no CRT,
and no writable executable section. USER32/GDI32 resolve from the system directory.
The runner checks the pinned original EXE and makes a task-owned reference.exe copy.
The collector maps that copy only as data/image resources (LoadLibraryExW flags
0x60), never executing its entry point or imports. This differs from the original
game's own GetModuleHandle; loader equivalence remains an explicit open question.

The exact LF2_CURSOR resource bytes and three fresh LoadImageA bitmap lifetimes
are recorded. Each uses IMAGE_BITMAP, zero dimensions and LR_CREATEDIBSECTION
0x2000. GetObjectW must return the complete DIBSECTION with bounded 11×19/8bpp/
plane-1 storage before its owned bitmap pointer is read. The complete storage is
sampled before and after GetDIBColorTable on an owned memory DC. Prior selection
is restored; object/DC release results and every failure remain in the record.
No foreign-process memory or bitmap-storage write is involved.

The capture includes pointer-width fields, destination seeds, raw responses,
resource bytes, OS/process/machine information and system-module paths. Module
file hashes collected by the runner describe its filesystem view; WOW64 limits
remain explicit. Pixel snapshots do not prove write coverage, universal initial
values, determinism, DirectDraw color keys, font rasterization or a complete frame.

The runner observes each child for at most 60 seconds. A timeout retains an
incomplete live-process record and stops the runner without terminating or
retrying that child. This behavior was corrected during author inspection before
any Windows execution; the earlier runner and correction record are preserved.
PowerShell was unavailable on the build host, so actual runner syntax/execution
validation remains open. The validator enforces the trusted manifest, reference
bytes, process provenance, descriptors, storage and palette coverage. Its output
always distinguishes structural verification from compatibility acceptance.

## Checks and preserved artifacts

All 54 synthetic tests passed: 27 finite API/IO stimuli on each architecture,
including short/failed/zero writes, existing output, resource and function failures,
invalid descriptors, null storage, top-down storage, partial/failed palette,
selection/restoration/cleanup failure and changed storage. These execute only the
new collector in Unicorn with explicitly synthetic bytes and responses. They are
not original-game or actual-Windows evidence. Partial and failure outputs remain.

Two final nine-file kits are byte-identical. Their PE bytes match the tested first
build. The existing NLS binaries were inspected with the inspector's unchanged
default import contract; no historical capture was rerun. Python syntax checks
passed. The only shared-tool change is an optional explicit import-set parameter
in build_windows_nls_probe.py; its previous bytes are preserved.

Artifacts are under the task-owned X5 directory
`windows-cursor-bitmap-probe-20260926` within this session's research root:

| Artifact | Verified result | SHA-256 |
| --- | --- | --- |
| Final manifest | 9 kit files | 5095cad6cb12159112c5ec0266cfdb125e39337907b3401bcedc8522b261485f |
| Kit ZIP | 29,322 bytes; exact members, CRC and bytes | 666602cbbaf04e99502459e09e79ff1d84c16c6c13c34017d9761bc471921469 |
| Transfer ISO | 921,600 bytes; read-only mounted, 9 files matched | 16521fefb88b07b4c9c8c161c22d4e2d5dcdc6a2596d21222fd6aa282e2d7840 |
| artifacts1.tar | 3,010,560 bytes; 148 members, bytes/modes/ns mtimes verified | e39fa64c9354b98d1fad88086ee6987321724d99269c5ba7f67650b0cb016143 |

The owned ISO device was ejected after verification; VM media was not changed.
All build/test jobs are terminal with exit 0. Ten prior input pins were preserved,
with the declared shared-tool edit separately recorded. Baseline assets, historical
masks/expectations, immutable AGENTS archive and Native sources/fixtures are unchanged.
Independent review is unavailable and remains open; author checks are not review.

## Future Windows capture

After normal guest setup, choose and verify a real task-owned game-copy path.
Example invocation from the copied kit (paths below are illustrative):

```powershell
.\run_windows_cursor_bitmap_probe.ps1 -ReferenceExe 'C:\NTSD-Research\game\NTSD 2.4.exe' -OutputDirectory 'C:\NTSD-Research\cursor-001' -EnvironmentDescription 'Actual Windows build, UTM ARM64, Windows x86 translation' -Architecture both
```

Host validation after returning the complete capture:

```sh
python3 tools/verify_windows_cursor_bitmap_capture.py /path/to/cursor-001 --manifest-sha256 5095cad6cb12159112c5ec0266cfdb125e39337907b3401bcedc8522b261485f
```

The Windows EULA approval arrived during packaging; Accept had not yet been pressed
at publication. Next: continue the existing installer, then validate the runner and
perform separately bounded guest observations. CrossOver remains available.
Actual Windows pixels and initialization, own-module loader equivalence, NLS,
GDI fonts/device behavior, original frame/game comparison, independent review,
Native raster integration and full match/game acceptance remain open. Existing
safety refusals remain unchanged. This checked preparation is progress, not a
completion or blocked-goal declaration.
