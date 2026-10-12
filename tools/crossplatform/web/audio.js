// The browser host's sound output (docs/research/TVOS_WEB.md W2b-3): an
// AudioWorklet that plays the worker's shared ring of interleaved stereo
// Float32 frames. Header (Int32): [0] frames written, [1] frames read,
// [2] underruns (a quantum short after the first frame), [3] frames played,
// [4] peak × 1e6 since the start, [5] frames owed: played short while the
// worker's loop stalled, which it renders and drops to keep wall-clock time.
// The worker keeps about 150 ms queued.
class NTSDRing extends AudioWorkletProcessor {
  constructor(options) {
    super();
    const sab = options.processorOptions.ring;
    this.header = new Int32Array(sab, 0, 8);
    this.frames = new Float32Array(sab, 32);
    this.mask = this.frames.length / 2 - 1;   // a power-of-two capacity
  }
  process(inputs, outputs) {
    const [left, right] = outputs[0], n = left.length, h = this.header;
    const write = Atomics.load(h, 0), read = Atomics.load(h, 1);
    const take = Math.min(n, (write - read) | 0);
    let peak = 0;
    for (let i = 0; i < take; i++) {
      const at = ((read + i) & this.mask) * 2, l = this.frames[at], r = this.frames[at + 1];
      left[i] = l; if (right) right[i] = r;
      peak = Math.max(peak, Math.abs(l), Math.abs(r));
    }
    for (let i = take; i < n; i++) { left[i] = 0; if (right) right[i] = 0; }
    if (take < n && Atomics.load(h, 3) > 0) { Atomics.add(h, 2, 1); Atomics.add(h, 5, n - take); }
    Atomics.store(h, 1, (read + take) | 0);
    Atomics.add(h, 3, take);
    const p = Math.round(peak * 1e6); if (p > Atomics.load(h, 4)) Atomics.store(h, 4, p);
    return true;
  }
}
registerProcessor('ntsd-ring', NTSDRing);
