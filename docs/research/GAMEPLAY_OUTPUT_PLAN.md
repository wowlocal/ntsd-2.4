# Gameplay output and return acceptance plan

The controlled criteria below are accepted in [GAMEPLAY_OUTPUT](GAMEPLAY_OUTPUT.md).
The initialized join remains open, independent of the concurrent result-layout publication.
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

Then join both initialized result-layout parents through their retained actual
return. That join, the application window, Windows runs, audio/pixel/latency
measurements, continuous ticks, full match and clean-Mac delivery remain open.
