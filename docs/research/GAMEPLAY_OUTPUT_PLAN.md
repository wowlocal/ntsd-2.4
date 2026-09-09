# Gameplay output and return acceptance plan

The controlled criteria below are accepted in [GAMEPLAY_OUTPUT](GAMEPLAY_OUTPUT.md).
The initialized join is accepted in [GAMEPLAY_RETURN](GAMEPLAY_RETURN.md).
Next is [CONTINUOUS_GAMEPLAY_PLAN](CONTINUOUS_GAMEPLAY_PLAN.md).
Recover the complete `422994..4229cc` gameplay output sequence and the normal
`422a95..422ab8/ret4` return from the pinned game EXE, SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.

The source study executes the original `41bc90..41bcd0` prologue to establish
the saved registers, aligned stack, SEH link and normal cookie. It then enters
the declared output context at422994. This deliberately omits the intervening
gameplay body; it is a controlled output/return comparison, not an initialized
tick. No control pointer or protection structure is damaged. Actual initialized
continuations must separately retain their own caller state through this path.

Memory/register/instruction traces are needed to recover observable ordering,
global mutation, font truncation, queue ownership and normal return restoration.
The real mode label, mutable bitmap font, bitmap/clip helpers, notice/volume
overlay, VC80 sprintf, presentation and queued-sound helpers execute on one
Unicorn CPU at CW023f. COM/GDI and CRT thread responses are declared boundaries;
they are not host or Windows device measurements.

Finite controlled acceptance criteria:

1. Execute mode label,4028a0 overlay,43e940 presentation,419e60 sound and the
   actual422ab8 return in their original order, covering enabled and disabled
   device gates, all presentation modes, notice timer boundaries, both volume
   keys, source music-query/read failures and signed queue arithmetic.
2. Compare complete globals and write masks, immutable supplied bitmap records,
   all ordered font/GDI/COM/sound requests, actual format bytes and helper returns.
   Preserve the new volume for the subsequent sound drain in the same call.
3. Verify source saved registers, stack cleanup, original SEH restoration and
   normal cookie-check execution. Preserve raw source bytes and hashes.
4. Compose the existing native helpers atomically. A failure during a late sound
   request must roll back earlier label, overlay and queue mutations. External
   output events must be buffered until the enclosing tick commits.
5. Verify raw and packaged fixtures without changing previously accepted pins.

Both initialized result-layout parents now match through their retained actual
match and dispatcher returns. The application engine join, Windows runs,
audio/pixel/latency measurements, continuous ticks, full match and clean-Mac
delivery remain open.

## Initialized acceptance

`oracle_gameplay_return.py` continues each fresh accepted result-layout parent
on the same original CPU. It retains the actual41bc90 and4246b0 caller frames,
executes422ab8/ret4,424746's held-button clear and428805/ret4. The supplied COM
method adapters bind already created buffers; no queue flag, sound buffer word,
Actor, result backing or saved machine frame is injected. Record those adapter
bindings separately from game state and preserve enabled sound.

Acceptance requires both complete source parents unchanged, full native
before/after state from its own reconstruction, exact label/GDI/present/sound
order, loaded resource ownership, global writes and unchanged heap masks. Trace
the actual entries and both returns to prove stack/saved-register/SEH restoration;
check every prior FPU checkpoint and the new output/return checkpoints. Verify
raw and packaged artifacts and all prior pins. Even a fully returned first tick
does not establish continuous ticks, a complete match, app integration or Windows.
