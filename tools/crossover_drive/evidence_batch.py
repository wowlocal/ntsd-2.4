#!/usr/bin/env python3
"""Collect a random_vs.py batch into an evidence JSON: per seed the recording,
background, difficulty, both Summary dumps and the comparison.
usage: evidence_batch.py BATCH_DIR OUT.json DESCRIPTION"""
import contextlib
import hashlib
import io
import json
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE)); sys.path.insert(0, str(HERE.parent))
import compare_summaries  # noqa: E402
import lfr_checksum  # noqa: E402

EXE = "/Volumes/X5/ntsd-2.4-research/goal-100-20261002/crossplay-game/NTSD 2.4_2.0a/NTSD 2.4.exe"
BG = ['District', 'SandCountry', 'Cave', 'Deep', 'Hideout', 'Rain', 'SnowCountry', 'River', 'Forest', 'Arena', 'RamenPlace',
      'Springs', 'Academy', 'CastleRoof', 'Valley', 'Grassland', 'Path']


def main(batch, out, description):
    key = lfr_checksum.writer_key(EXE); cases = []
    for d in sorted((p for p in Path(batch).iterdir() if p.is_dir() and p.name.isdigit()), key=lambda p: int(p.name)):
        # record_original.py keeps the original's recording beside the dumps.
        recs = sorted(d.glob("*.lfr")) or sorted((d / "overlay").rglob("*.lfr"))
        if not recs or not (d / "original.json").exists(): cases.append(dict(seed=int(d.name), result="incomplete")); continue
        raw = recs[-1].read_bytes(); r = lfr_checksum.decode(raw, key); bg = struct.unpack_from("<i", r, 0x1A4)[0]
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf): status = compare_summaries.main(str(d / "mac.json"), str(d / "original.json"))
        cases.append(dict(seed=int(d.name), background=BG[bg] if 0 <= bg < len(BG) else f"built-in {bg}",
                          difficulty=struct.unpack_from("<i", r, 0)[0], recordingSHA256=hashlib.sha256(raw).hexdigest(),
                          result=buf.getvalue().strip(), equal=status == 0,
                          mac=json.loads((d / "mac.json").read_text()), original=json.loads((d / "original.json").read_text())))
    ev = dict(date="2026-10-03", loop="docs/CROSSPLAY_LOOP.md", description=description,
              comparison="every Summary field per seat, ticks, winner, mode, War totals; HP as Alive/Dead (regenerating HP of a living fighter is a note)",
              cases=cases)
    Path(out).write_text(json.dumps(ev, indent=1) + "\n")
    print(sum(c.get("equal", False) for c in cases), "of", len(cases), "equal")


if __name__ == "__main__":
    main(*sys.argv[1:4])
