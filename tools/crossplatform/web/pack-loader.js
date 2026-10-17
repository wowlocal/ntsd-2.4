// The browser host's data loader (docs/research/TVOS_WEB.md W5): a worker
// beside the game's that brings a static folder's data (web_app.py build) to
// the game's synchronous reads.
//
// The folder's files sit in a few packs, each a 64-byte header and the files
// concatenated in the order the program first reads them, sent
// brotli-compressed (Content-Encoding: br, so the browser decodes them): a
// first visit makes ~20 requests instead of one per file (1,521, each a round
// trip to the host, which took ~45 s from a CDN before W5). A pack streams
// into the origin's private file system (OPFS, through a synchronous access
// handle, which only a worker has) or, where that fails (a private window, an
// older browser, another tab holding the files, a full disk), into memory, and
// each file is ready once its last byte is stored, so the program reads while
// the rest is still arriving. Nothing from a response is stored before its
// header shows the bytes are the pack the index lists (a host that strips or
// doubles the encoding sends other bytes: the pack fails, loudly). A later
// visit finds the packs it completed and fetches none of them (unless
// another tab, or a page still closing, holds them). The startup pack (pack 0)
// loads at once; the others after the page says go (the program compiled:
// until then the module has the bandwidth), two at a time in order; a pack
// the program asks for before its turn starts at once. Lazy packs (the music
// tracks, the program file) load only when asked for. In memory, the
// schedule holds about 320 MiB ahead of the program's reads (a pack being
// fetched counts; one the program asks for goes past it), and a pack goes
// once every file in it has been read (read again, it is fetched again).
//
// Messages: from the page {kind: 'init', key, packs: [{url, raw, lazy,
// header}], files: [{pack, offset, size}], state, memory} (memory: keep
// nothing in OPFS, a check of that path; state: a
// SharedArrayBuffer, one Int32 per file: 1 here once the file is ready, 2 if
// it cannot come), {kind: 'port', port} (the game worker's MessagePort) and
// {kind: 'go'}; to the page {kind: 'progress', ...report} and {kind:
// 'failed', url, error}. From the game worker, which never yields while the
// program runs: {op: 'read', id, buffer} (a SharedArrayBuffer: an Int32
// status pair, then room for the file; the status becomes 1 with the bytes in
// place, or 2 when they cannot come) and {op: 'want', id} (fetch it, no
// answer).
'use strict';

const MAGIC = 'NTSDPACK', FORMAT = 1, BUDGET = 320 << 20, STALL = 30000;
let packs = [], files = [], ready = null, key = '', directory = null, started = false, serving = false, broken = null, timer = null;
const pending = new Map();   // file id → read buffers waiting for it
const early = [];   // the game worker's requests before the loader serves
const report = { stored: 0, total: 0, packsDone: 0, reused: 0, opfs: 0, memory: 0, released: 0, failed: 0, reads: 0, waits: 0 };
const sleep = ms => new Promise(ok => setTimeout(ok, ms));

self.onmessage = ({ data: m }) => {
  if (m.kind === 'init') init(m).catch(e => stop(`loader: ${e && e.stack || e}`));
  else if (m.kind === 'port') m.port.onmessage = ({ data }) => request(data);
  else if (m.kind === 'go') { started = true; if (serving) schedule(); }
};

async function init(m) {
  key = m.key; ready = new Int32Array(m.state);
  packs = m.packs.map((p, index) => ({ ...p, index, files: [], stored: 0, next: 0, state: 'idle', store: null, urgent: false, read: new Set(), complete: false }));
  files = m.files.map((f, id) => ({ ...f, id }));
  for (const f of files) packs[f.pack].files.push(f);
  for (const p of packs) p.files.sort((a, b) => a.offset - b.offset);
  report.total = packs.reduce((n, p) => n + (p.lazy ? 0 : p.raw), 0);
  directory = m.memory ? null : await privateFolder(key);
  for (const p of packs) await reuse(p);   // before anything is scheduled: a pack fetched meanwhile would overwrite a complete one
  serving = true;
  schedule();
  for (const r of early.splice(0)) request(r);
  progress();
}
// A loader that cannot start answers every read with a failure (the game
// sees it at once instead of waiting for its timeout).
function stop(text) {
  broken = text;
  postMessage({ kind: 'failed', url: '', error: text });
  for (const r of early.splice(0)) if (r.op === 'read') answer(r.buffer, 2);
}

// This build's folder in OPFS (ntsd-data/<the data folder's name>); an
// older build's folder is removed (unless another tab still has it open).
async function privateFolder(name) {
  try {
    const all = await (await navigator.storage.getDirectory()).getDirectoryHandle('ntsd-data', { create: true });
    try { for await (const other of all.keys()) if (other !== name) all.removeEntry(other, { recursive: true }).catch(() => {}); } catch {}
    return await all.getDirectoryHandle(name, { create: true });
  } catch { return null; }
}

// A pack an earlier visit stored whole: its marker file says so, and its
// size must match (and its header, checked when stored, is read again).
async function reuse(p) {
  if (!directory) return;
  let handle = null;
  try {
    handle = await (await directory.getFileHandle(`${p.index}`)).createSyncAccessHandle();
    if (!await intact(p, handle)) throw new Error('incomplete');
  } catch { if (handle) try { handle.close(); } catch {} return; }
  p.store = { kind: 'opfs', handle }; p.state = 'done'; p.stored = p.raw; p.complete = true; report.reused++; report.packsDone++;
  advance(p);
}
async function intact(p, handle) {
  try {
    await directory.getFileHandle(`${p.index}.done`);   // NotFoundError when absent
    if (handle.getSize() !== p.raw) return false;
    if (p.header) { const head = new Uint8Array(p.header); readInto(handle, head, 0); if (headerError(p, head)) return false; }
    return true;
  } catch { return false; }
}

const inMemory = () => !directory || report.memory > 0;   // where OPFS failed, the next packs will be held in memory too
const held = () => packs.reduce((n, p) => n + ((p.store && p.store.kind === 'memory') || (!p.store && p.state === 'loading' && inMemory()) ? p.raw : 0), 0);
function schedule() {
  if (!serving) return;
  let lanes = 2 - packs.filter(p => p.state === 'loading' && !p.urgent).length;
  const memory = inMemory();
  for (const p of packs) {
    if (lanes <= 0) break;
    if (p.state !== 'idle' || p.lazy || p.complete || (p.index > 0 && !started)) continue;   // a released pack comes back only when read
    if (memory && held() > 0 && held() + p.raw > BUDGET) break;   // ahead enough: wait for the program to read
    lanes--; load(p);
  }
}
function need(p) { if (p.state === 'idle') { p.urgent = true; load(p); } }

async function load(p) {
  p.state = 'loading'; tick();
  for (let attempt = 0; ; attempt++) {
    try { await fetchInto(p); break; }
    catch (e) {
      if (e.fatal || attempt >= 2) { p.state = 'failed'; report.failed++; fail(p, e); schedule(); return; }
      await sleep(1000 * (attempt + 1));   // a dropped or stalled connection: the whole pack again
    }
  }
  p.state = 'done'; p.urgent = false; p.complete = true; report.packsDone++;
  release(p); progress(); schedule();
}

const fatal = text => Object.assign(new Error(text), { fatal: true });
async function fetchInto(p) {
  if (!p.store) {
    p.store = await storeFor(p);
    if (p.store.intact) { delete p.store.intact; p.stored = p.raw; report.reused++; advance(p); return; }   // complete after all (a page that was closing held it)
  }
  const control = new AbortController();
  let idle = setTimeout(() => control.abort(), STALL);
  try {
    const response = await fetch(p.url, { signal: control.signal });
    if (!response.ok) {
      if (response.body) response.body.cancel().catch(() => {});
      const e = new Error(`${p.url}: HTTP ${response.status}`); e.fatal = response.status < 500 && response.status !== 408 && response.status !== 429;
      throw e;
    }
    const reader = response.body.getReader();
    // Each response's header is checked before any of its bytes are stored;
    // a retry rewrites what the first attempt stored with the same bytes.
    const head = p.header ? new Uint8Array(p.header) : null;
    let at = 0, headAt = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      clearTimeout(idle); idle = setTimeout(() => control.abort(), STALL);
      let chunk = value;
      if (head && headAt < head.length) {
        const take = Math.min(head.length - headAt, chunk.length);
        head.set(chunk.subarray(0, take), headAt); headAt += take; chunk = chunk.subarray(take);
        if (headAt < head.length) continue;
        const wrong = headerError(p, head);
        if (wrong) { reader.cancel().catch(() => {}); throw fatal(`${p.url}: ${wrong} (the host altered it: its Content-Encoding?)`); }
        write(p, head, 0); at = head.length;
      }
      if (at + chunk.length > p.raw) { reader.cancel().catch(() => {}); throw fatal(`${p.url}: more than the listed ${p.raw} bytes (the host altered it: its Content-Encoding?)`); }
      if (chunk.length) { write(p, chunk, at); at += chunk.length; }
      if (at > p.stored) { p.stored = at; advance(p); }
    }
    if (at !== p.raw) throw fatal(`${p.url}: ${at} bytes, listed ${p.raw} (the host altered it: its Content-Encoding?)`);
    advance(p);   // zero-length files at the end
    if (p.store.kind === 'opfs') {
      try { p.store.handle.flush(); await directory.getFileHandle(`${p.index}.done`, { create: true }); } catch {}
    }
  } finally { clearTimeout(idle); }
}
// A pack's header: 'NTSDPACK', the format and pack number (Int32 LE), the
// pack's whole size (UInt64 LE), the data folder's name (NUL-padded).
function headerError(p, head) {
  const view = new DataView(head.buffer, head.byteOffset, head.byteLength), text = b => String.fromCharCode(...b).replace(/\0+$/, '');
  if (text(head.subarray(0, 8)) !== MAGIC) return 'not a pack';
  if (view.getInt32(8, true) !== FORMAT || view.getInt32(12, true) !== p.index) return 'another pack';
  if (Number(view.getBigUint64(16, true)) !== p.raw || text(head.subarray(24, p.header)) !== key) return "another build's pack";
  return null;
}

async function storeFor(p) {
  if (directory) {
    let handle = null;
    try {   // the handle first: a pack another tab holds keeps its marker and its bytes
      handle = await (await directory.getFileHandle(`${p.index}`, { create: true })).createSyncAccessHandle();
      if (await intact(p, handle)) return { kind: 'opfs', handle, intact: true };
      await directory.removeEntry(`${p.index}.done`).catch(() => {});   // incomplete until stored again
      handle.truncate(0); report.opfs++;
      return { kind: 'opfs', handle };
    } catch { if (handle) try { handle.close(); } catch {} }
  }
  report.memory++;
  return { kind: 'memory', bytes: new Uint8Array(p.raw) };
}

function write(p, chunk, at) {
  if (p.store.kind === 'opfs') {
    try { if (p.store.handle.write(chunk, { at }) === chunk.length) return; } catch {}
    toMemory(p);   // a full disk or a lost handle: the rest in memory
  }
  p.store.bytes.set(chunk, at);
}
// What OPFS already holds is copied into memory; if it cannot be read back,
// the pack starts over in memory (its files are not ready meanwhile).
function toMemory(p) {
  const bytes = new Uint8Array(p.raw), handle = p.store.handle;
  let kept = true;
  try { readInto(handle, bytes.subarray(0, p.stored), 0); } catch { kept = false; }
  try { handle.close(); } catch {}
  p.store = { kind: 'memory', bytes }; report.memory++;
  if (!kept) {
    for (const f of p.files) Atomics.store(ready, f.id, 0);
    p.stored = 0; p.next = 0;
    throw new Error(`${p.url}: storage failed; loading it again`);
  }
}

function advance(p) {
  while (p.next < p.files.length && p.files[p.next].offset + p.files[p.next].size <= p.stored) {
    const f = p.files[p.next++];
    Atomics.store(ready, f.id, 1);
    const waiting = pending.get(f.id);
    if (waiting) { pending.delete(f.id); for (const b of waiting) serve(f, b); }
  }
}

function request(m) {
  if (broken) { if (m.op === 'read') answer(m.buffer, 2); return; }
  if (!serving) { early.push(m); return; }
  const f = files[m.id];
  if (!f) { if (m.op === 'read') answer(m.buffer, 2); return; }
  const p = packs[f.pack];
  if (m.op === 'want') { need(p); return; }
  report.reads++;
  const state = Atomics.load(ready, f.id);
  if (state === 1) { serve(f, m.buffer); return; }
  if (state === 2 || p.state === 'failed') { answer(m.buffer, 2); return; }
  report.waits++;
  if (!pending.has(f.id)) pending.set(f.id, []);
  pending.get(f.id).push(m.buffer);
  need(p);
}

function serve(f, buffer) {
  const p = packs[f.pack], out = new Uint8Array(buffer, 8, f.size);
  try {
    if (p.store.kind === 'memory') out.set(p.store.bytes.subarray(f.offset, f.offset + f.size));
    else readInto(p.store.handle, out, f.offset);
    answer(buffer, 1);
  } catch (e) {
    postMessage({ kind: 'failed', url: p.url, error: `reading a file back: ${e && e.message || e}` });
    answer(buffer, 2); return;
  }
  if (p.store.kind === 'memory') { p.read.add(f.id); release(p); }
}
// A pack held in memory goes once each of its files has been read (a file
// read again brings it back); OPFS packs stay.
function release(p) {
  if (p.state !== 'done' || !p.store || p.store.kind !== 'memory' || p.read.size < p.files.length) return;
  for (const f of p.files) Atomics.store(ready, f.id, 0);
  p.store = null; p.state = 'idle'; p.stored = 0; p.next = 0; p.read.clear(); p.urgent = false;
  report.released++; progress(); schedule();
}
function readInto(handle, out, at) {
  let n;
  try { n = handle.read(out, { at }); }   // straight into the shared buffer where the browser allows it
  catch { const copy = new Uint8Array(out.length); n = handle.read(copy, { at }); out.set(copy); }
  if (n !== out.length) throw new Error(`${n} of ${out.length} bytes`);
}
function answer(buffer, status) { const s = new Int32Array(buffer, 0, 2); Atomics.store(s, 0, status); Atomics.notify(s, 0); }

// A pack that cannot come: its files not yet stored read as failed (the
// game sees an error; a waiting music track opens, fails and says so); those
// a checked response already stored stay readable.
function fail(p, e) {
  for (const f of p.files) {
    if (Atomics.load(ready, f.id) === 1) continue;
    Atomics.store(ready, f.id, 2);
    const waiting = pending.get(f.id);
    if (waiting) { pending.delete(f.id); for (const b of waiting) answer(b, 2); }
  }
  if (p.store && p.store.kind === 'memory' && p.stored === 0) p.store = null;   // nothing kept: not held
  postMessage({ kind: 'failed', url: p.url, error: String(e && e.message || e) });
}

function progress() {
  report.stored = packs.reduce((n, p) => n + (p.lazy ? 0 : p.complete ? p.raw : Math.min(p.stored, p.raw)), 0);   // a released pack stays counted
  postMessage({ kind: 'progress', ...report });
}
function tick() {   // progress while something loads
  if (timer) return;
  timer = setInterval(() => { progress(); if (!packs.some(p => p.state === 'loading')) { clearInterval(timer); timer = null; } }, 250);
}
