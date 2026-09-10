# Menu sound initialization: bounded acceptance plan

Recover the original producer of the five menu sound buffers consumed by
character/network screens: whole401970 and caller43d08e..43d100, including all
five actual4014e0 children. The pinned original EXE and original five WAV files
are the behavioral reference; Unicorn2.1.4 is development tooling only.

This is an independent controlled WinMain segment. Earlier CRT/NLS, window,
settings, graphics, music and worker initialization are not resumed or claimed.
The original window token, prior globals, saved registers and the three pending
memset arguments are explicit entry inputs. The full WinMain prologue and
stack lifetime remain open. The bundled library does not patch these bodies;
this study must verify that fact against the accepted installer inventory, and
must not label a pristine controlled call as an installed startup chain.

Low-level execution is needed to recover exact HRESULT checks, stores, stack
cleanup and caller continuation after an individual WAV failure. DirectSound,
MMIO, MessageBox and allocator/copy boundaries use the retained WAV adapter;
no Windows sound DLL, real device or Windows filesystem is exercised.

Finite acceptance:

1. Execute both initial backing patterns, DirectSoundCreate zero/nonzero
   results (including positive failure), and ignored cooperative-level errors.
   Verify exact default GUID, outer pointer, window and level1 requests.
2. Execute the five original files in order, preserving low16(destination)
   format overlap, PCM bytes/masks, complete descriptors, temporary lifetime,
   returned buffer ownership and every whole child return. Test ordinary open,
   descend, read and ascend failures at each of the five positions; preserve
   continued later loads and leaks reported by the shared loader.
3. Exercise buffer-lost restoration and ignored final Lock/Unlock/Close errors
   with explicitly valid API outputs. Failed CreateSoundBuffer stops at the
   already declared40187a boundary before unsafe continuation; it is a separate
   native rejection with full rollback, never a successful whole segment.
   Allocator exhaustion remains the retained loader's unverified boundary;
   this stage does not execute a null payload dereference.
4. Compare full global bytes/write masks and ordered stores, all requests and
   their live global state, every WAV allocation/buffer byte and mask. Verify
   actual caller end43d100 and ESP=entryESP+12 (three pending memset arguments),
   not a WinMain return. Inventory actual instruction bytes separately from
   static starts. Native must compose shared OriginalWaveLoader, retain its own
   buffers, and never import an expected after-state or unknown stack word.
5. Verify missing-success-output and late-observer native rollback. Run new
   comparisons plus retained WAV and network-menu tests in an isolated native
   export. Accept immutable lossless fixture only after raw comparisons pass;
   verify all225 old pins, source/WAV identity, full raw/packed bytes and blobs,
   and rerun packaged tests. Preserve foreign work and terminal job evidence.

Full initialized WinMain, app wiring, playback/device behavior, Windows,
complete matches and clean-Mac acceptance remain open after this dependency.

Finite controlled acceptance is complete in
[MENU_SOUND_STARTUP](MENU_SOUND_STARTUP.md):112 whole segment matches and ten
separate stopped-create rejections. Raw and packaged comparisons retain the
prior WAV/network corpora. The full application goal remains open.
