#!/usr/bin/env python3
"""Validate result recording and completed tail helpers with one raw test build.

Run only after every source capture is terminal. All original verifiers and full
native comparisons run before publication. Publish in dependency order with the
same intermediate fixture pins; packaged regression remains a separate check.
This reduces repeated resource-triggered builds, not the verification scope.
"""
import json
import os
import subprocess
from accept_initialized_gameplay import ROOT,FIXTURES,digest,publish
from accept_result_recording import validate as recording
from accept_gameplay_result_recording import validate_captures as gameplay
from accept_bitmap_font import validate as font
from accept_mode_label import validate as label
from accept_playback_information import validate as information
from accept_queued_sound import validate as sound


def main():
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous=json.loads((ROOT/'build/research/replay-writer-fixture-pins.json').read_bytes())
    assert len(pins)==len(previous)==175 and pins==previous
    report,raw=recording();stages=[('result-recording',[("result-recording",report,raw)],176)]
    stages.append(('gameplay-result-recording',gameplay(),178))
    for name,validator,count in [('bitmap-font',font,179),('mode-label',label,180),('playback-information',information,181),('queued-sound',sound,182)]:
        report,raw=validator();stages.append((name,[(name,report,raw)],count))
    for _,captures,_ in stages:
        for name,report,_ in captures:
            path=ROOT/'build/research'/f'{name}-acceptance-validation.json';path.write_text(json.dumps(report,indent=2)+'\n')
    environment=dict(os.environ,NTSD_RESULT_RECORDING_CORPUS=str(ROOT/'build/original/result-recording.json'),
        NTSD_GAMEPLAY_RESULT_RECORDING_DIRECTORY=str(ROOT/'build/original'),NTSD_BITMAP_FONT_CORPUS=str(ROOT/'build/original/bitmap-font.json'),
        NTSD_MODE_LABEL_CORPUS=str(ROOT/'build/original/mode-label.json'),NTSD_PLAYBACK_INFORMATION_CORPUS=str(ROOT/'build/original/playback-information.json'),
        NTSD_QUEUED_SOUND_CORPUS=str(ROOT/'build/original/queued-sound.json'))
    selected='|'.join(['OriginalResultRecordingTests','OriginalGameplayResultRecordingTests','OriginalBitmapFontTests','OriginalModeLabelTests',
                       'OriginalPlaybackInformationTests','OriginalQueuedSoundTests','OriginalReplayWriterTests','OriginalReplayCompressionTests','OriginalReplayFileOutputTests'])
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter',selected],env=environment,check=True)
    for pin_name,captures,count in stages:
        publish(captures,pins,pin_name=pin_name+'-fixture-pins.json')
        assert len(pins)==count
    print('PUBLISHED',len(pins)-len(previous),'new immutable fixtures;',len(previous),'old pins unchanged;',len(pins),'current pins',flush=True)


if __name__=='__main__':main()
