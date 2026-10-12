// A minimal WASI preview-1 host for a browser worker: the browser runner's
// harness (docs/research/TVOS_WEB.md W2a), as wasi_run.mjs is Node's.
//
// The page posts {program, args, env, mounts}; each mount is a guest folder
// served by the runner (web_run.mjs) under /m/<index>/, or from a static
// folder (W2b-4c: the mount's url, listed by its manifest, a JSON list of
// {path, dir, size}, instead of the runner's ?list). Without the runner
// (config.runner false) stdout and stderr go to the console and the end is
// a message to the page. Files load lazily
// with synchronous XHR (allowed in a worker), so the 700 MB app bundle is
// never copied whole; a folder is listed once (?list). Writes stay in memory
// and reach the runner when the file closes (PUT); folders made, files
// removed and renames go at once. Read-only mounts refuse every change with
// EROFS. A mount the page keeps (persist, TVOS_WEB W2b-4a: the saves, in the
// browser's IndexedDB) arrives whole with the config, and its changes go to
// the page as messages, which stores them in order (the worker never yields,
// so it cannot wait on the browser's asynchronous storage itself). The
// browser host also gets a /tmp in memory (memory, never stored), as WASI
// programs expect one: without /save its overlay goes there (W2b-4b; before,
// Foundation trapped creating a folder outside every mount).
// stdout and stderr are buffered and posted in order. poll_oneoff
// sleeps with Atomics.wait, which needs a cross-origin-isolated page.
//
// With a frame buffer (config.frames, a SharedArrayBuffer from the page), the
// worker also provides the browser host's "ntsd" imports (TVOS_WEB W2b):
// present hands an XRGB8888 crop to the page, which draws it. At exit the
// worker waits up to 5 s for the page to report what it drew.
'use strict';

const ERR = { SUCCESS: 0, ACCES: 2, BADF: 8, EXIST: 20, INVAL: 28, IO: 29, ISDIR: 31, NOENT: 44, NOSYS: 52,
              NOTDIR: 54, NOTEMPTY: 55, ROFS: 69, SPIPE: 70, XDEV: 75 };
const RIGHT_FD_WRITE = 64n;
const FILETYPE = { CHAR: 2, DIR: 3, FILE: 4 };
const OFLAGS = { CREAT: 1, DIRECTORY: 2, EXCL: 4, TRUNC: 8 };
const FDFLAG_APPEND = 1;

class Exit extends Error { constructor(code) { super(`exit ${code}`); this.code = code; } }

function request(method, url, body, type = 'text') {
  const x = new XMLHttpRequest();
  x.open(method, url, false);
  if (type === 'arraybuffer') x.responseType = 'arraybuffer';
  x.send(body ?? null);
  return x;
}
// A file or a listing read: up to three tries of 60 s each (a network error,
// a stalled connection or a server error is tried again after 0.5 then 1 s;
// then the game sees the failure).
const pause = new Int32Array(new SharedArrayBuffer(4));
let reading = null;   // the page's fetch gate (W3f): raised while the program waits on a read
function read(url, type = 'text') {
  if (reading) Atomics.add(reading, 0, 1);
  try { return readOnce(url, type); } finally { if (reading) Atomics.sub(reading, 0, 1); }
}
function readOnce(url, type) {
  let x = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    if (attempt) Atomics.wait(pause, 0, 0, 500 * attempt);   // a moment before trying again
    x = new XMLHttpRequest(); x.open('GET', url, false); x.timeout = 60000;   // allowed for a worker's synchronous request
    if (type === 'arraybuffer') x.responseType = 'arraybuffer';
    try { x.send(); } catch { continue; }
    if (x.status > 0 && x.status < 500) return x;
  }
  return x;
}

let nextInode = 1n;
class Node {
  constructor(kind, mount, path, size = 0) {
    this.kind = kind; this.mount = mount; this.path = path; this.inode = nextInode++;
    this.children = null;          // folders: Map name → Node, listed on first use
    this.data = null; this.size = size; this.dirty = false;   // files: bytes on first read
    this.deleted = false;
  }
  url(extra = '') { return `${this.mount.url}/${this.path.split('/').map(encodeURIComponent).join('/')}${extra}`; }
  list() {
    if (this.kind !== 'dir') return null;
    if (this.mount.persist || this.mount.memory || this.mount.listed) return this.children ??= new Map();
    if (this.children === null) {
      const x = read(this.url('?list'));
      if (x.status !== 200 && x.status !== 404) throw new Error(`list ${this.path}: ${x.status}`);
      this.children = new Map();
      if (x.status === 200) for (const e of JSON.parse(x.responseText)) {
        const p = this.path ? `${this.path}/${e.n}` : e.n;
        this.children.set(e.n, new Node(e.d ? 'dir' : 'file', this.mount, p, e.s ?? 0));
      }
    }
    return this.children;
  }
  bytes() {
    if (this.mount.persist || this.mount.memory) return this.data ??= new Uint8Array(0);
    if (this.data === null) {
      const x = read(this.url(), 'arraybuffer');
      if (x.status !== 200) throw new Error(`read ${this.path}: ${x.status}`);
      const data = new Uint8Array(x.response);
      // A read-only mount's file must arrive at its listed size (a manifest's
      // or the runner's listing): a host that strips or doubles a
      // Content-Encoding (W3b's precompressed forms) fails here, loudly.
      if (!this.mount.writable && data.length !== this.size)
        throw new Error(`read ${this.path}: ${data.length} bytes, listed ${this.size} (the host altered it: Content-Encoding?)`);
      this.data = data; this.size = data.length;
    }
    return this.data;
  }
}

let memory = null, stdout = [], stderr = [], buffered = 0, runner = true;
const decoder = new TextDecoder(), encoder = new TextEncoder();
const view = () => new DataView(memory.buffer);
const bytesAt = (ptr, len) => new Uint8Array(memory.buffer, ptr, len);
const text = (ptr, len) => decoder.decode(bytesAt(ptr, len).slice());

function flush() {
  for (const [name, chunks] of [['stdout', stdout], ['stderr', stderr]]) {
    if (!chunks.length) continue;
    const total = chunks.reduce((n, c) => n + c.length, 0), all = new Uint8Array(total);
    let at = 0; for (const c of chunks) { all.set(c, at); at += c.length; }
    if (!runner) { (name === 'stdout' ? console.log : console.warn)(decoder.decode(all)); chunks.length = 0; continue; }
    const x = request('POST', `/${name}`, all); chunks.length = 0;
    if (x.status !== 200) throw new Error(`${name} not delivered: ${x.status}`);
  }
  buffered = 0;
}

// A message for the runner's stderr, or the console without one.
function say(text) { if (runner) request('POST', '/stderr', text); else console.warn(text); }
self.onmessage = async ({ data: config }) => {
  runner = config.runner !== false;
  if (config.fetchGate) reading = new Int32Array(config.fetchGate);
  try { await run(config); }
  catch (e) {
    const text = `web_run: worker: ${e && e.stack || e}\n`;
    if (!runner) { console.error(text); postMessage({ kind: 'exit', code: 134, text }); return; }
    try { request('POST', '/stderr', text); } finally { request('POST', '/exit?code=134'); }
  }
};

async function run(config) {
  const sleeper = new Int32Array(new SharedArrayBuffer(4));
  const given = config.frames && !config.mounts.some(m => m.guest === '/tmp') ? [{ guest: '/tmp', writable: true, memory: true }] : [];
  const mounts = [...config.mounts, ...given].map((m, i) => ({ ...m, url: m.url ?? `/m/${i}` }));
  for (const m of mounts) if (m.manifest) {   // a static folder's listing
    const r = await fetch(m.manifest); if (!r.ok) throw new Error(`manifest ${m.manifest}: ${r.status}`);
    m.entries = await r.json(); m.listed = true;
  }
  // A kept mount's tree as the page loaded it (entries: path, dir, data);
  // folders on the way to an entry exist even without their own record.
  function seed(root, entries) {
    for (const e of [...entries].sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0))) {
      const parts = e.path.split('/').filter(Boolean); let dir = root;
      for (let i = 0; i < parts.length && dir && dir.kind === 'dir'; i++) {
        const last = i === parts.length - 1, kids = dir.list();
        let node = kids.get(parts[i]);
        if (!node) {
          node = new Node(last && !e.dir ? 'file' : 'dir', root.mount, parts.slice(0, i + 1).join('/'));
          if (node.kind === 'file' && e.data) { node.data = e.data; node.size = e.data.length; }
          else if (node.kind === 'file') node.size = e.size ?? 0;   // a listed file: its bytes on first read
          kids.set(parts[i], node);
        }
        dir = node;
      }
    }
    return root;
  }
  const fds = [
    { kind: 'stdin' }, { kind: 'stdout' }, { kind: 'stderr' },
    ...mounts.map(m => ({ kind: 'node', node: m.persist || m.listed ? seed(new Node('dir', m, ''), m.entries ?? []) : new Node('dir', m, ''), pos: 0, preopen: m.guest })),
  ];
  const args = config.args.map(a => encoder.encode(a + '\0'));
  const env = Object.entries(config.env).map(([k, v]) => encoder.encode(`${k}=${v}\0`));

  const fdNode = fd => (fds[fd] && fds[fd].kind === 'node') ? fds[fd] : null;
  function resolve(dirfd, path, { parent = false } = {}) {
    const base = fdNode(dirfd); if (!base) return { error: ERR.BADF };
    const parts = path.split('/').filter(p => p && p !== '.');
    let node = base.node, stack = [];
    const last = parent ? parts.pop() : null;
    for (const p of parts) {
      if (p === '..') { if (!stack.length) return { error: ERR.ACCES }; node = stack.pop(); continue; }
      const kids = node.list(); if (!kids) return { error: ERR.NOTDIR };
      const next = kids.get(p); if (!next) return { error: ERR.NOENT };
      stack.push(node); node = next;
    }
    if (parent) { if (node.kind !== 'dir') return { error: ERR.NOTDIR }; return { dir: node, name: last }; }
    return { node };
  }
  function filestat(node, ptr) {
    const v = view();
    v.setBigUint64(ptr, 0n, true); v.setBigUint64(ptr + 8, node.inode, true);
    v.setUint8(ptr + 16, node.kind === 'dir' ? FILETYPE.DIR : FILETYPE.FILE);
    v.setBigUint64(ptr + 24, 1n, true);
    v.setBigUint64(ptr + 32, BigInt(node.kind === 'dir' ? 0 : (node.data ? node.data.length : node.size)), true);
    v.setBigUint64(ptr + 40, 0n, true); v.setBigUint64(ptr + 48, 0n, true); v.setBigUint64(ptr + 56, 0n, true);
  }
  // A change to a writable mount: a request to the runner's folder, or for a
  // kept mount a message the page stores (in the order sent).
  let stores = 0;   // store messages sent: the page applies that many before it reports
  function change(node, op, to) {
    if (node.mount.memory) return true;
    if (node.mount.persist) { postMessage({ kind: 'store', guest: node.mount.guest, op, path: node.path, to }); stores++; return true; }
    return request('POST', node.url(op === 'rename' ? `?op=rename&to=${encodeURIComponent(to)}` : `?op=${op}`)).status === 200;
  }
  function upload(node) {
    if (!node.dirty || node.deleted) return;
    if (node.mount.memory) { node.dirty = false; return; }
    if (node.mount.persist) {
      const data = (node.data ?? new Uint8Array(0)).slice();
      postMessage({ kind: 'store', guest: node.mount.guest, op: 'put', path: node.path, data }, [data.buffer]);
      stores++; node.dirty = false; return;
    }
    const x = request('PUT', node.url(), node.data ?? new Uint8Array(0));
    if (x.status !== 200) throw new Error(`write ${node.path}: ${x.status}`);
    node.dirty = false;
  }
  const writable = node => node.mount.writable;
  const now = () => BigInt(Math.round((performance.timeOrigin + performance.now()) * 1e6));

  const wasi = {
    args_sizes_get(argc, size) { const v = view(); v.setUint32(argc, args.length, true); v.setUint32(size, args.reduce((n, a) => n + a.length, 0), true); return 0; },
    args_get(argv, buf) { const v = view(); for (const a of args) { v.setUint32(argv, buf, true); argv += 4; bytesAt(buf, a.length).set(a); buf += a.length; } return 0; },
    environ_sizes_get(count, size) { const v = view(); v.setUint32(count, env.length, true); v.setUint32(size, env.reduce((n, a) => n + a.length, 0), true); return 0; },
    environ_get(list, buf) { const v = view(); for (const a of env) { v.setUint32(list, buf, true); list += 4; bytesAt(buf, a.length).set(a); buf += a.length; } return 0; },
    clock_res_get(id, ptr) { view().setBigUint64(ptr, 1000n, true); return 0; },
    clock_time_get(id, precision, ptr) {
      if (id === 0) view().setBigUint64(ptr, now(), true);
      else if (id === 1) view().setBigUint64(ptr, BigInt(Math.round(performance.now() * 1e6)), true);
      else return ERR.INVAL;
      return 0;
    },
    fd_write(fd, iovs, count, written) {
      const v = view(); let total = 0;
      const f = fds[fd]; if (!f) return ERR.BADF;
      for (let i = 0; i < count; i++) {
        const ptr = v.getUint32(iovs + 8 * i, true), len = v.getUint32(iovs + 8 * i + 4, true);
        const chunk = bytesAt(ptr, len).slice(); total += len;
        if (f.kind === 'stdout' || f.kind === 'stderr') {
          (f.kind === 'stdout' ? stdout : stderr).push(chunk); buffered += len;
        } else if (f.kind === 'node') {
          const n = f.node; if (n.kind !== 'file') return ERR.ISDIR; if (!writable(n)) return ERR.ROFS;
          const data = n.bytes(), at = f.append ? data.length : f.pos, end = at + len;
          if (end > data.length) {
            // Grow within the buffer's spare room when there is some; else double it.
            if (data.byteOffset === 0 && data.buffer.byteLength >= end) n.data = new Uint8Array(data.buffer, 0, end);
            else { const room = new Uint8Array(Math.max(end, data.buffer.byteLength * 2)); room.set(data); n.data = room.subarray(0, end); }
          }
          n.data.set(chunk, at); n.size = n.data.length; n.dirty = true; f.pos = end;
        } else return ERR.BADF;
      }
      if (buffered > 1 << 16) flush();
      v.setUint32(written, total, true); return 0;
    },
    fd_read(fd, iovs, count, read) {
      const v = view(), f = fds[fd]; if (!f) return ERR.BADF;
      if (f.kind === 'stdin') { v.setUint32(read, 0, true); return 0; }
      if (f.kind !== 'node' || f.node.kind !== 'file') return ERR.BADF;
      const data = f.node.bytes(); let total = 0;
      for (let i = 0; i < count; i++) {
        const ptr = v.getUint32(iovs + 8 * i, true), len = v.getUint32(iovs + 8 * i + 4, true);
        const n = Math.max(0, Math.min(len, data.length - f.pos));
        bytesAt(ptr, n).set(data.subarray(f.pos, f.pos + n)); f.pos += n; total += n;
        if (n < len) break;
      }
      v.setUint32(read, total, true); return 0;
    },
    fd_pread(fd, iovs, count, offset, read) {
      const v = view(), f = fdNode(fd); if (!f || f.node.kind !== 'file') return ERR.BADF;
      const data = f.node.bytes(); let at = Number(offset), total = 0;
      for (let i = 0; i < count; i++) {
        const ptr = v.getUint32(iovs + 8 * i, true), len = v.getUint32(iovs + 8 * i + 4, true);
        const n = Math.max(0, Math.min(len, data.length - at));
        bytesAt(ptr, n).set(data.subarray(at, at + n)); at += n; total += n;
        if (n < len) break;
      }
      v.setUint32(read, total, true); return 0;
    },
    fd_seek(fd, offset, whence, result) {
      const f = fdNode(fd); if (!f) return fds[fd] ? ERR.SPIPE : ERR.BADF;
      const size = f.node.kind !== 'file' ? 0 : (f.node.data ? f.node.data.length : f.node.size);
      const pos = [0, f.pos, size][whence] + Number(offset);
      if (whence > 2 || pos < 0) return ERR.INVAL;
      f.pos = pos; view().setBigUint64(result, BigInt(pos), true); return 0;
    },
    fd_tell(fd, result) { const f = fdNode(fd); if (!f) return ERR.BADF; view().setBigUint64(result, BigInt(f.pos), true); return 0; },
    fd_close(fd) {
      const f = fds[fd]; if (!f) return ERR.BADF;
      if (f.preopen) return ERR.BADF;
      if (f.kind === 'node' && f.node.kind === 'file') {
        upload(f.node);
        // An unchanged file's bytes go when no other descriptor has it open:
        // they would otherwise stay in the worker beside the linear memory.
        // A kept mount's stay: nothing could read them back.
        if (!f.node.mount.persist && !f.node.mount.memory && !f.node.dirty && !fds.some((g, i) => i !== fd && g && g.node === f.node)) f.node.data = null;
      }
      fds[fd] = undefined; return 0;
    },
    fd_sync(fd) { const f = fdNode(fd); if (f && f.node.kind === 'file') upload(f.node); return 0; },
    fd_fdstat_get(fd, ptr) {
      const f = fds[fd]; if (!f) return ERR.BADF; const v = view();
      v.setUint8(ptr, f.kind === 'node' ? (f.node.kind === 'dir' ? FILETYPE.DIR : FILETYPE.FILE) : FILETYPE.CHAR);
      v.setUint16(ptr + 2, f.append ? FDFLAG_APPEND : 0, true);
      v.setBigUint64(ptr + 8, 0xffffffffffffffffn, true); v.setBigUint64(ptr + 16, 0xffffffffffffffffn, true);
      return 0;
    },
    fd_fdstat_set_flags(fd, flags) { const f = fds[fd]; if (!f) return ERR.BADF; f.append = (flags & FDFLAG_APPEND) !== 0; return 0; },
    fd_filestat_get(fd, ptr) {
      const f = fds[fd]; if (!f) return ERR.BADF;
      if (f.kind !== 'node') { const v = view(); for (let i = 0; i < 64; i += 8) v.setBigUint64(ptr + i, 0n, true); v.setUint8(ptr + 16, FILETYPE.CHAR); return 0; }
      filestat(f.node, ptr); return 0;
    },
    fd_filestat_set_size(fd, size) {
      const f = fdNode(fd); if (!f || f.node.kind !== 'file') return ERR.BADF; if (!writable(f.node)) return ERR.ROFS;
      const data = f.node.bytes(), n = Number(size), next = new Uint8Array(n); next.set(data.subarray(0, Math.min(n, data.length)));
      f.node.data = next; f.node.size = n; f.node.dirty = true; return 0;
    },
    fd_filestat_set_times() { return 0; },
    fd_prestat_get(fd, ptr) {
      const f = fds[fd]; if (!f || !f.preopen) return ERR.BADF;
      const v = view(); v.setUint8(ptr, 0); v.setUint32(ptr + 4, encoder.encode(f.preopen).length, true); return 0;
    },
    fd_prestat_dir_name(fd, ptr, len) {
      const f = fds[fd]; if (!f || !f.preopen) return ERR.BADF;
      bytesAt(ptr, len).set(encoder.encode(f.preopen).subarray(0, len)); return 0;
    },
    fd_readdir(fd, buf, len, cookie, used) {
      const f = fdNode(fd); if (!f) return ERR.BADF; const kids = f.node.list(); if (!kids) return ERR.NOTDIR;
      const entries = [['.', f.node], ['..', f.node], ...kids.entries()];
      const v = view(); let at = 0;
      for (let i = Number(cookie); i < entries.length && at < len; i++) {
        const [name, node] = entries[i], bytes = encoder.encode(name), head = new Uint8Array(24), hv = new DataView(head.buffer);
        hv.setBigUint64(0, BigInt(i + 1), true); hv.setBigUint64(8, node.inode, true);
        hv.setUint32(16, bytes.length, true); hv.setUint8(20, node.kind === 'dir' ? FILETYPE.DIR : FILETYPE.FILE);
        const all = new Uint8Array(24 + bytes.length); all.set(head); all.set(bytes, 24);
        const n = Math.min(all.length, len - at); bytesAt(buf + at, n).set(all.subarray(0, n)); at += n;
      }
      v.setUint32(used, at, true); return 0;
    },
    path_filestat_get(fd, flags, ptr, len, out) {
      const r = resolve(fd, text(ptr, len)); if (r.error) return r.error; filestat(r.node, out); return 0;
    },
    path_filestat_set_times() { return 0; },
    path_open(fd, dirflags, ptr, len, oflags, base, inheriting, fdflags, out) {
      const path = text(ptr, len);
      let r = resolve(fd, path);
      if (r.error === ERR.NOENT && (oflags & OFLAGS.CREAT)) {
        const p = resolve(fd, path, { parent: true }); if (p.error) return p.error;
        if (!writable(p.dir)) return ERR.ROFS;
        const node = new Node('file', p.dir.mount, p.dir.path ? `${p.dir.path}/${p.name}` : p.name);
        node.data = new Uint8Array(0); node.dirty = true; p.dir.list().set(p.name, node); r = { node };
      } else if (r.error) return r.error;
      else if ((oflags & OFLAGS.CREAT) && (oflags & OFLAGS.EXCL)) return ERR.EXIST;
      const node = r.node;
      if ((oflags & OFLAGS.DIRECTORY) && node.kind !== 'dir') return ERR.NOTDIR;
      if ((base & RIGHT_FD_WRITE) && node.kind === 'file' && !writable(node)) return ERR.ROFS;
      if ((oflags & OFLAGS.TRUNC) && node.kind === 'dir') return ERR.ISDIR;
      if ((oflags & OFLAGS.TRUNC) && node.kind === 'file') {
        if (!writable(node)) return ERR.ROFS;
        node.data = new Uint8Array(0); node.size = 0; node.dirty = true;
      }
      fds.push({ kind: 'node', node, pos: 0, append: (fdflags & FDFLAG_APPEND) !== 0 });
      view().setUint32(out, fds.length - 1, true); return 0;
    },
    path_create_directory(fd, ptr, len) {
      const p = resolve(fd, text(ptr, len), { parent: true }); if (p.error) return p.error;
      if (!writable(p.dir)) return ERR.ROFS; const kids = p.dir.list(); if (kids.has(p.name)) return ERR.EXIST;
      const node = new Node('dir', p.dir.mount, p.dir.path ? `${p.dir.path}/${p.name}` : p.name); node.children = new Map();
      if (!change(node, 'mkdir')) return ERR.IO;
      kids.set(p.name, node); return 0;
    },
    path_remove_directory(fd, ptr, len) {
      const p = resolve(fd, text(ptr, len), { parent: true }); if (p.error) return p.error;
      if (!writable(p.dir)) return ERR.ROFS; const node = p.dir.list().get(p.name); if (!node) return ERR.NOENT;
      if (node.kind !== 'dir') return ERR.NOTDIR; if (node.list().size) return ERR.NOTEMPTY;
      if (!change(node, 'rmdir')) return ERR.IO;
      p.dir.list().delete(p.name); return 0;
    },
    path_unlink_file(fd, ptr, len) {
      const p = resolve(fd, text(ptr, len), { parent: true }); if (p.error) return p.error;
      if (!writable(p.dir)) return ERR.ROFS; const node = p.dir.list().get(p.name); if (!node) return ERR.NOENT;
      if (node.kind === 'dir') return ERR.ISDIR;
      if (!change(node, 'unlink')) return ERR.IO;
      node.deleted = true; p.dir.list().delete(p.name); return 0;
    },
    path_rename(fd, ptr, len, fd2, ptr2, len2) {
      const a = resolve(fd, text(ptr, len), { parent: true }), b = resolve(fd2, text(ptr2, len2), { parent: true });
      if (a.error) return a.error; if (b.error) return b.error;
      if (a.dir.mount !== b.dir.mount) return ERR.XDEV;
      if (!writable(a.dir) || !writable(b.dir)) return ERR.ROFS;
      const node = a.dir.list().get(a.name); if (!node) return ERR.NOENT;
      const to = b.dir.path ? `${b.dir.path}/${b.name}` : b.name, replaced = b.dir.list().get(b.name);
      if (replaced === node) return 0;   // the same entry: nothing to do, as rename(2)
      if (node.kind === 'dir' && to.startsWith(node.path + '/')) return ERR.INVAL;   // into itself
      if (replaced && replaced.kind === 'dir' && node.kind !== 'dir') return ERR.ISDIR;
      if (replaced && replaced.kind !== 'dir' && node.kind === 'dir') return ERR.NOTDIR;
      if (replaced && replaced.kind === 'dir' && replaced.list().size) return ERR.NOTEMPTY;
      if (node.kind === 'file') upload(node);
      if (!change(node, 'rename', to)) return ERR.IO;
      if (replaced) replaced.deleted = true;
      a.dir.list().delete(a.name);
      const move = (n, path) => { n.path = path; if (n.children) for (const [k, c] of n.children) move(c, `${path}/${k}`); };
      move(node, to); b.dir.list().set(b.name, node); return 0;
    },
    path_link() { return ERR.NOSYS; },
    path_symlink() { return ERR.NOSYS; },
    path_readlink() { return ERR.INVAL; },
    poll_oneoff(subs, events, count, done) {
      if (count === 0) return ERR.INVAL;
      let v = view(); const clocks = [], others = [];
      for (let i = 0; i < count; i++) {
        const s = subs + 48 * i, tag = v.getUint8(s + 8);
        if (tag === 0) {
          const id = v.getUint32(s + 16, true), timeout = v.getBigUint64(s + 24, true), abs = (v.getUint16(s + 40, true) & 1) !== 0;
          const nowNs = id === 0 ? now() : BigInt(Math.round(performance.now() * 1e6));
          clocks.push({ s, ms: Number(abs ? timeout - nowNs : timeout) / 1e6 });
        } else others.push(s);
      }
      // fd subscriptions are always ready (files and pipes never block here);
      // otherwise sleep until the earliest clock and report the clocks due.
      const wait = others.length ? 0 : Math.min(...clocks.map(c => c.ms));
      if (wait > 0) Atomics.wait(sleeper, 0, 0, wait);
      v = view(); let n = 0;
      const fired = [...others, ...clocks.filter(c => c.ms <= Math.max(wait, 0)).map(c => c.s)];
      for (const s of fired) {
        const e = events + 32 * n++;
        v.setBigUint64(e, v.getBigUint64(s, true), true); v.setUint16(e + 8, 0, true); v.setUint8(e + 10, v.getUint8(s + 8));
        v.setBigUint64(e + 16, 0n, true); v.setUint16(e + 24, 0, true);
      }
      v.setUint32(done, n, true); return 0;
    },
    proc_exit(code) { throw new Exit(code); },
    random_get(ptr, len) {
      for (let at = 0; at < len; at += 65536) crypto.getRandomValues(bytesAt(ptr + at, Math.min(65536, len - at)));
      return 0;
    },
  };

  // A JS failure inside an import (a failed request, a bad listing) is EIO
  // with a line on stderr, never a silent wrong answer.
  for (const [name, fn] of Object.entries(wasi)) {
    if (name === 'proc_exit') continue;
    wasi[name] = (...a) => {
      try { return fn(...a); }
      catch (e) { if (e instanceof Exit) throw e; stderr.push(encoder.encode(`web_run: ${name}: ${e && e.message || e}\n`)); return ERR.IO; }
    };
  }
  // The browser host's page functions (NTSDWeb's "ntsd" imports). The worker
  // never yields while the game runs (its loop sleeps in Atomics.wait), so it
  // cannot draw on the page itself: present copies the crop into the page's
  // shared frame buffer under a sequence lock, and the page draws it.
  const frames = config.frames ?? null;   // SharedArrayBuffer: Int32 header[8], then pixels
  const header = frames ? new Int32Array(frames, 0, 8) : null, presented = { count: 0, width: 0, height: 0, skipped: 0, popup: false };
  // Input and questions (W2b-2), all in shared memory the page fills:
  // config.input: Int32 [write, read, then 256 events of 5 Int32 (kind, a, b, c, d)];
  // config.pads: Int32 [count, then 2 × (x, y, buttons, connected)];
  // config.dialog: Int32 [answered, answer]; the question itself is posted.
  const input = config.input ? new Int32Array(config.input) : null;
  const pads = config.pads ? new Int32Array(config.pads) : null;
  const dialog = config.dialog ? new Int32Array(config.dialog) : null;
  const audioHeader = config.audio ? new Int32Array(config.audio.ring, 0, 8) : null;
  const audioFrames = config.audio ? new Float32Array(config.audio.ring, 32) : null;
  const audioTarget = config.audio ? Math.round(config.audio.rate * 0.15) : 0;
  const audioMask = audioFrames ? audioFrames.length / 2 - 1 : 0;
  const ntsd = {
    input(ptr, capacity) {
      if (!input) return 0;
      const write = Atomics.load(input, 0);   // a 256-event ring; counters wrap as Int32
      let read = Atomics.load(input, 1), n = 0;
      const out = new Int32Array(memory.buffer, ptr, capacity * 5);
      while (read !== write && n < capacity) {
        const at = 2 + (read & 255) * 5;
        for (let k = 0; k < 5; k++) out[n * 5 + k] = input[at + k];
        read = (read + 1) | 0; n++;
      }
      Atomics.store(input, 1, read);
      return n;
    },
    gamepads() { return pads ? Atomics.load(pads, 0) : 0; },
    gamepad(id, ptr) {
      const out = new Int32Array(memory.buffer, ptr, 4);
      for (let k = 0; k < 4; k++) out[k] = pads && id >= 0 && id < 2 ? Atomics.load(pads, 1 + id * 4 + k) : 0;
    },
    ask(textPtr, textCount, captionPtr, captionCount, buttonsPtr, buttonsCount) {
      const buttons = text(buttonsPtr, buttonsCount).split('\0').slice(0, -1);
      flush();   // the program's output so far reaches the runner before the wait
      if (!dialog) return 0;
      Atomics.store(dialog, 0, 0);
      self.postMessage({ kind: 'ask', text: text(textPtr, textCount), caption: text(captionPtr, captionCount), buttons });
      Atomics.wait(dialog, 0, 0);   // until the player answers
      return Atomics.load(dialog, 1);
    },
    open(ptr, count) { self.postMessage({ kind: 'open', url: text(ptr, count) }); },
    // Sound (W2b-3): the page's ring (Int32 header [written, read, ...], then
    // a power of two of stereo Float32 frames), kept about 150 ms ahead.
    audioRate() { return config.audio ? config.audio.rate : 0; },
    audioSpace() {
      if (!audioHeader) return 0;
      const pending = (Atomics.load(audioHeader, 0) - Atomics.load(audioHeader, 1)) | 0;
      return Math.max(0, Math.min(audioTarget, audioMask + 1) - pending);
    },
    audioWrite(ptr, count) {
      if (!audioHeader) return;
      const source = new Float32Array(memory.buffer, ptr, count * 2), write = Atomics.load(audioHeader, 0);
      for (let i = 0; i < count; i++) {
        const at = ((write + i) & audioMask) * 2; audioFrames[at] = source[2 * i]; audioFrames[at + 1] = source[2 * i + 1];
      }
      Atomics.store(audioHeader, 0, (write + count) | 0);
    },
    audioOwed() { return audioHeader ? Atomics.exchange(audioHeader, 5, 0) : 0; },
    present(ptr, width, height, popup) {
      presented.count++; presented.width = width; presented.height = height;
      // Whether the game's full-screen popup presents (it fills the page in the
      // original format, WINDOW_SCALING S2); told to the page when it changes.
      if (((popup | 0) !== 0) !== presented.popup) { presented.popup = (popup | 0) !== 0; postMessage({ kind: 'popup', popup: presented.popup }); }
      if (!frames || width <= 0 || height <= 0) return;
      const n = width * height * 4;
      if (32 + n > frames.byteLength) { presented.skipped++; return; }
      Atomics.add(header, 0, 1);   // odd: being written
      header[1] = width; header[2] = height;
      new Uint8Array(frames, 32, n).set(new Uint8Array(memory.buffer, ptr, n));
      Atomics.add(header, 0, 1);   // even: complete
      Atomics.add(header, 3, 1);
    },
  };

  async function prefetch(listed) {
    const files = listed.flatMap(m => m.entries.filter(e => !e.dir && !e.path.endsWith('.wasm'))
      .map(e => ({ url: `${m.url}/${e.path.split('/').map(encodeURIComponent).join('/')}`, size: e.size || 0 })));
    if (!files.length) return null;
    // Only where the browser's cache serves the program's synchronous reads
    // afterwards (Chromium's does; Playwright's WebKit fetched every file
    // twice): one file fetched, then read as the program reads, and its
    // timing entry must show no transfer. Else the program fetches as it reads.
    const probe = files.shift();
    try { const r = await fetch(probe.url); if (r.ok) await r.arrayBuffer(); } catch {}
    if (performance.clearResourceTimings) performance.clearResourceTimings();
    read(probe.url, 'arraybuffer');
    const seen = performance.getEntriesByName ? performance.getEntriesByName(probe.url).pop() : null;
    if (!seen || seen.transferSize !== 0) { postMessage({ kind: 'progress', loaded: 0, total: 0, skipped: true }); return null; }
    // The page fetches the rest while the program runs (TVOS_WEB W3f: this
    // worker never yields once it does): the startup package first, which
    // the menu reads, then the others in listing order. A file the program
    // reads before its turn it fetches itself; the other request then finds
    // it in the cache or waits for the one under way.
    // Handed over once the module is in: before, the prefetch shared the
    // bandwidth with the 96 MB module, which the program waits for.
    const first = f => (/\/OriginalStartup\//.test(f.url) ? 0 : 1);
    return files.map((f, i) => ({ ...f, i })).sort((a, b) => first(a) - first(b) || a.i - b.i).map(({ url, size }) => ({ url, size }));
  }
  let code = 0;
  const started = performance.now();
  try {
    const imports = { wasi_snapshot_preview1: wasi, ntsd };
    // A static folder's files fetched in parallel by the page (a mount's
    // prefetch: the host caches them, web_app.py), so the program's
    // one-at-a-time reads come from the browser's cache; the probe runs while
    // the module compiles. Music tracks load when they play.
    const warm = prefetch(mounts.filter(m => m.listed && m.prefetch));
    let instance;
    try { ({ instance } = await WebAssembly.instantiateStreaming(fetch(config.program), imports)); }
    catch (e) {
      if (!(e instanceof TypeError)) throw e;   // e.g. a host that does not send application/wasm: compile from the bytes
      const r = await fetch(config.program); if (!r.ok) throw new Error(`program: ${r.status}`);
      ({ instance } = await WebAssembly.instantiate(await r.arrayBuffer(), imports));
    }
    const prefetching = await warm;
    if (prefetching) postMessage({ kind: 'prefetch', files: prefetching });
    memory = instance.exports.memory;
    instance.exports._start();
  } catch (e) {
    if (e instanceof Exit) code = e.code;
    else { stderr.push(encoder.encode(`web_run: ${e && e.stack || e}\n`)); code = 134; }
  }
  try { for (const f of fds) if (f && f.kind === 'node' && f.node.kind === 'file') upload(f.node); }
  catch (e) { stderr.push(encoder.encode(`web_run: upload ${e}\n`)); code = code || 134; }
  try { flush(); } catch (e) { say(`web_run: ${e.message}\n`); code = code || 134; }
  if (frames) {   // the page stores what it was sent and reports its canvas, then acknowledges
    Atomics.store(header, 6, stores); Atomics.store(header, 7, code); Atomics.store(header, 4, 1); Atomics.notify(header, 4);
    if (Atomics.wait(header, 5, 0, 5000) === 'timed-out')
      say('web_run: the page did not report its canvas within 5 s\n');
  }
  if (!runner) { postMessage({ kind: 'exit', code }); return; }
  request('POST', `/metrics`, JSON.stringify({ memoryBytes: memory ? memory.buffer.byteLength : 0,
                                               seconds: (performance.now() - started) / 1000, userAgent: navigator.userAgent,
                                               ...(frames ? { presented } : {}) }));
  request('POST', `/exit?code=${code}`);
}
