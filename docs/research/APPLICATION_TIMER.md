# Original application timer decision

[OriginalApplicationTimer](../../native/Sources/NTSDCore/OriginalApplicationTimer.swift)
matches2025 whole original43d157..43d1ef decisions at the declared external
call boundaries: baseline and8163 ordered requests agree. This is the timing
decision after the application finds no pending message. It does not execute
the game dispatcher, surface recovery, message loop or a real device.

The reference is the pinned original NTSD2.4 EXE, SHA256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
under Unicorn2.1.4. No CRT call is needed by this slice. Clock responses and
43e9a0's signed result are declared inputs;43e890 and Sleep are observed
external requests with explicit returns. Low-level execution recovers repeated
clock sampling, unsigned lateness tests, ESI baseline lifetime and signed sleep
clamping. All59 byte-checked instructions in this slice execute across the
corpus. Hooked boundary PCs and the unexecuted43d1ef stop are excluded.

## Exact request order

The normal branch uses33ms; speedFlag zero selects3ms. Any other flag selects
the normal branch. A fresh clock response first tests unsigned lateness against
the interval. If due, another response tests lateness against100; a third
response supplies `now-100` when clamping is necessary. The source reads the
target, increments baseline by the interval, and invokes the dispatcher once.
Its signed-negative result requests surface recovery. A final time response
then determines wrapped `baseline-now+interval`; only a signed-positive value
requests Sleep, capped at5ms.

Consequently, an iteration has two, three or four time reads. It does not
aggregate several dispatcher calls around one fixed `now`. The old
[OriginalClock](../../native/Sources/NTSDCore/OriginalClock.swift) and its
historical fixture remain unchanged; they describe the earlier normal-speed
aggregate and are not the new whole-iteration comparison.

The2025 cells combine three speed flags, three baselines including wrapping
positions, fifteen initial clock deltas around3/33/100 and large unsigned
values, five advances between reads, and three dispatcher-result signs.
Clock inputs are controlled responses, not measured wall-clock behavior.

| Observation | Count |
| --- | ---: |
|Clock requests|6129|
|Dispatcher requests|1215|
|Surface-recovery requests|405|
|Sleep requests|414|
|Iterations with2/3/4 clock reads|810 /351 /864|

Observed sleep arguments are1,2,3 and5ms;4ms is not exercised by this finite
corpus. All instruction starts are covered, not every possible input or branch
outcome combination. Source ESP, preserved EBX/EBP/EDI, declared CW023f and the
unchanged global byte region are checked separately. These controlled registers
and FPU setup do not come from an initialized own application chain.

## Native transaction and remaining composition

The timer commits only its own baseline after all callbacks succeed. A late
Sleep observer failure, after a due dispatch and recovery request, retains the
old baseline. This is a native observer-failure test; the source corpus does not
model an exception from Windows Sleep. An enclosing game operation must stage
its own state and buffer external effects. This timer test does not prove that
an already submitted draw or completed game callback can be undone.

[APPLICATION_MESSAGE_LOOP](APPLICATION_MESSAGE_LOOP.md) now compares message
processing,458580 counter and baseline from its own continuous startup, sharing
this timer. Dispatcher/recovery bodies remain declared there; a due own call
stops at actual43e9a0. The full43e9a0/43e890 and initialized game/device join
remain in [APPLICATION_TIMER_PLAN](APPLICATION_TIMER_PLAN.md). The native application
still uses its earlier Practice path. Linking NTSDNative in this build is not
an application-window, Windows, latency, full-match or clean-Mac check.

## Reproduction and immutable evidence

Source: [oracle_application_timer.py](../../tools/oracle_application_timer.py).
Static byte inventory: [inspect_application_timer.py](../../tools/inspect_application_timer.py).
Independent checks: [verify_application_timer.py](../../tools/verify_application_timer.py).
Acceptance: [accept_application_timer.py](../../tools/accept_application_timer.py).
Report: [application-timer.json](../evidence/application-timer.json).

Raw source is1337395 bytes, SHA256
`d4b47030d966c93c38eb7681a6b7d0313db7fecc17961e2e9b2b716a19c0dd4f`;
lossless packed fixture49043 bytes, SHA256
`ee66e26e9a6b7bb7cae675e0d138827260642c2ac1431222bef0133610580b74`.
All191 prior fixture pins remain unchanged; this milestone has192 pins.
Full restored bytes plus transport newline, complete JSON, lengths/hashes and
all10 private codec vendor files were independently verified. Fixture deflation
is research transport and does not replace the game's replay codec.

The native-only isolated5a0916a export includes only this timer and its test as
source overlays. Raw release2tests passed0.026s/build173.41s. Final packaged release2tests passed0.027s/build0.29s.
Process/source hashes are retained in
`build/research/application-timer-work.json`. Active-gameplay and paused-gameplay
work in the shared checkout were excluded from this comparison.
