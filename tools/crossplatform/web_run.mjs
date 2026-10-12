#!/usr/bin/env node
// Runs a wasm32-unknown-wasip1 program in a headless browser: the Web host's
// browser stage of the test harness (docs/research/TVOS_WEB.md W2a), with the
// same interface as wasi_run.mjs.
//
// Usage: node web_run.mjs [--map GUEST=HOST ...] [--ro GUEST=HOST ...]
//                         [--env KEY=VALUE ...] [--argv0 GUEST_PATH]
//                         [--metrics FILE] [--canvas] [--interactive]
//                         [--answer N] [--steps FILE] [--timeout SECONDS]
//                         [--serve PORT] [--persist GUEST] [--profile DIR] [--port PORT]
//                         -- PROGRAM.wasm [ARGS ...]
//        node web_run.mjs --url URL [--steps FILE | --for SECONDS] [--profile DIR] [--timeout SECONDS]
// (also [--precompressed] with a program)
//
// A local node:http server serves web/run.html and web/wasi-worker.js with
// cross-origin isolation headers, the program, and each mount under
// /m/<index>/ (file bytes, or a folder listing with ?list); --map mounts take
// the worker's writes (PUT, mkdir, unlink, rmdir, rename), --ro mounts refuse
// them in the worker. The browser is Playwright's cached
// chrome-headless-shell ($NTSD_BROWSER names another Chromium binary), or with
// NTSD_BROWSER_ENGINE=webkit Playwright's cached WebKit (Safari's engine). The
// program's stdout and stderr are this process's, its exit code this
// process's exit code; --metrics writes the worker's report (linear memory
// size, seconds, user agent) as JSON. --canvas gives the browser host's
// present a page canvas (TVOS_WEB W2b); the worker's report then counts the
// presents, and beside it page.json holds what the page drew (draws, torn
// reads, the first non-black frame read back and compared with its source)
// and canvas-last.png the page canvas at exit. --interactive lets the page
// send keyboard, mouse and gamepad input (W2b-2); --answer N answers every
// question the game asks with button N at once (logged on stderr). --steps
// FILE (Chromium) drives the page over the DevTools protocol: a JSON list of
// {"at": seconds after the page loaded, then "key": KeyboardEvent.code,
// "click": [x, y] in canvas pixels, "capture": NAME (the canvas saved as
// NAME.png beside the report), "log": a page expression to print,
// "chord": [codes] (keys held together by their codes only, no modifier flags
// or characters: e.g. ["AltLeft", "Enter"]),
// "viewport": [width, height] (the page's window size, W2b-4b), "press": a
// CSS selector (a player's click on that page element) or "profile":
// "start" | NAME (the worker's CPU profile from start to here, saved as
// NAME.cpuprofile beside the report, W3c)}. The page's own dialogs (confirm)
// are accepted and logged.
// An interactive page waits for a player's click, key or gamepad button
// unless --answer automates it (a --steps click can be that gesture).
// --serve PORT starts no browser: it serves the page on 127.0.0.1:PORT (or
// localhost) for a player's own browser and keeps serving after the game
// ends, so reloading the page plays again. --persist GUEST (with --canvas)
// mounts a folder the page keeps in the browser's IndexedDB (the saves,
// TVOS_WEB W2b-4a); the page's report then lists what it keeps. --profile DIR
// runs the browser on a profile folder kept after the run (else a temporary
// one), so a second run sees what the first one stored — on the same --port:
// --url URL (Chromium) opens a page served elsewhere (a static folder,
// web_app.py, W2b-4c) instead of this runner's, runs --steps on it and ends
// after the last step (1 when the page's program ended with a non-zero code),
// or (any engine) keeps it open --for SECONDS (no program, no reports: the
// page's and the worker's output is the browser console's; with --steps the
// worker's console is printed on stderr).
// --original-window shows the original window (the frame at one CSS pixel per
// pixel, WINDOW_SCALING S2). --precompressed serves a file's NAME.br or NAME.gz form (web_app.py build
// --compress) with Content-Encoding when the browser accepts it, as a host
// would (W3b), so scenarios run from the delivered files.
// the browser keeps storage per origin, port included (else a free port); a
// profile serves one run at a time. For the same reason the page is served on
// 127.0.0.1 only: localhost is sent there, so a player's saves stay in one
// place.
// --timeout ends the run (exit 124) after SECONDS (default 3300); a run ended
// by a signal also closes its browser, so none is left running.
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync, statSync, lstatSync, readdirSync, rmSync, renameSync, unlinkSync, rmdirSync, existsSync, realpathSync } from 'node:fs';
import { join, resolve, dirname, sep } from 'node:path';
import { tmpdir, homedir } from 'node:os';
import process, { argv, env, exit } from 'node:process';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const external = argv.includes('--url') ? argv[argv.indexOf('--url') + 1] : null;
if (external) argv.push('--', '');   // no program
const sepAt = argv.indexOf('--');
if (sepAt < 0 || sepAt + 1 >= argv.length) {
  console.error('usage: web_run.mjs [--map GUEST=HOST ...] [--ro GUEST=HOST ...] [--env KEY=VALUE ...] [--argv0 PATH] [--metrics FILE] -- PROGRAM.wasm [ARGS ...]');
  exit(2);
}
const options = argv.slice(2, sepAt);
const [program, ...args] = argv.slice(sepAt + 1);
const mounts = [], guestEnv = { TZ: env.TZ ?? 'Etc/GMT-1' };
let holdFor = null, precompressed = false, originalWindow = false;
const served = { br: 0, gzip: 0, plain: 0 };   // --precompressed: responses by encoding
let argv0 = program, metricsFile = null, canvas = false, interactive = false, answer = null, steps = null, timeout = 3300, serve = null, kept = null, port = 0;
for (let i = 0; i < options.length; i += 2) {
  if (options[i] === '--canvas') { canvas = true; i--; continue; }
  if (options[i] === '--interactive') { interactive = true; i--; continue; }
  if (options[i] === '--answer') { answer = Number(options[i + 1]); continue; }
  if (options[i] === '--steps') { steps = JSON.parse(readFileSync(options[i + 1], 'utf8')); continue; }
  if (options[i] === '--timeout') { timeout = Number(options[i + 1]); continue; }
  if (options[i] === '--serve') { serve = Number(options[i + 1]); continue; }
  if (options[i] === '--persist' && options[i + 1]?.startsWith('/')) { mounts.push({ guest: options[i + 1], writable: true, persist: true }); continue; }
  if (options[i] === '--profile' && options[i + 1]) { kept = resolve(options[i + 1]); continue; }
  if (options[i] === '--url') continue;
  if (options[i] === '--for') { holdFor = Number(options[i + 1]); continue; }
  if (options[i] === '--precompressed') { precompressed = true; i--; continue; }
  if (options[i] === '--original-window') { originalWindow = true; i--; continue; }
  if (options[i] === '--port') {
    port = Number(options[i + 1]);
    if (!Number.isInteger(port) || port < 0 || port > 65535) { console.error(`web_run.mjs: bad port ${options[i + 1]}`); exit(2); }
    continue;
  }
  const [name, value] = [options[i], options[i + 1]];
  const at = value?.indexOf('=') ?? -1;
  if ((name === '--map' || name === '--ro') && at > 0)
    mounts.push({ guest: value.slice(0, at), host: resolve(value.slice(at + 1)), writable: name === '--map' });
  else if (name === '--env' && at > 0) guestEnv[value.slice(0, at)] = value.slice(at + 1);
  else if (name === '--argv0' && value) argv0 = value;
  else if (name === '--metrics' && value) metricsFile = value;
  else { console.error(`web_run.mjs: bad option ${name} ${value}`); exit(2); }
}
if (external && steps && holdFor !== null) { console.error('web_run.mjs: --url takes --steps or --for, not both'); exit(2); }
if (mounts.some(m => m.persist) && !canvas) { console.error('web_run.mjs: --persist needs --canvas (the page keeps it)'); exit(2); }

const headers = { 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp',
                  'Cross-Origin-Resource-Policy': 'same-origin', 'Cache-Control': 'no-store' };
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.wasm': 'application/wasm' };
let browser = null, finished = false, profile = null, alive = 0;
// The program's output: the worker hears back only once the write has
// completed (a pipe from Python is non-blocking, so a synchronous write could
// stop half-way), and the process exits only after both streams drain.
const out = (fd, data) => new Promise(ok => (fd === 1 ? process.stdout : process.stderr).write(data, ok));
const say = text => { process.stderr.write(text); };
function finish(code) {
  if (finished) return; finished = true;
  server.close();
  let leaving = false;
  const done = () => {
    if (leaving) return; leaving = true;
    try { if (profile && profile !== kept) rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }); } catch {}
    process.stdout.write('', () => process.stderr.write('', () => exit(code)));
  };
  if (!browser || browser.exitCode !== null || browser.signalCode !== null) return done();
  browser.once('exit', done); browser.kill('SIGKILL');
  setTimeout(done, 5000).unref();
}
process.on('SIGTERM', () => finish(143)); process.on('SIGINT', () => finish(130));
process.on('SIGHUP', () => finish(129)); process.on('SIGALRM', () => finish(142));
function body(req) {
  return new Promise(ok => { const parts = []; req.on('data', c => parts.push(c)); req.on('end', () => ok(Buffer.concat(parts))); });
}
// A mount-relative path inside the mount's folder, or null: checked as text
// and again after resolving links in its nearest existing ancestor.
function hostPath(mount, rel) {
  const p = resolve(mount.host, rel), inside = q => q === root || q.startsWith(root + sep);
  const root = realpathSync(mount.host);
  if (!(p === mount.host || p.startsWith(mount.host + sep))) return null;
  // lstat, not existsSync: a dangling link is an existing entry to check.
  const present = q => { try { lstatSync(q); return true; } catch { return false; } };
  let probe = p; while (!present(probe)) probe = dirname(probe);
  return inside(realpathSync(probe)) ? p : null;
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://local');
  const send = (status, data = '', type = 'text/plain; charset=utf-8', extra = {}) => {
    if (env.NTSD_WEB_DEBUG) say(`web_run.mjs: ${req.method} ${req.url.slice(0, 120)} -> ${status}\n`);
    res.writeHead(status, { ...headers, 'Content-Type': type, ...extra }); res.end(data);
  };
  // A file's bytes, or with --precompressed its .br/.gz form the request accepts (q > 0).
  const file = (path, type, forms = true) => {   // forms: read-only files only (a writable one may be rewritten)
    if (precompressed && forms) {
      const accepted = new Set((req.headers['accept-encoding'] ?? '').split(',').map(p => p.trim().split(';'))
        .filter(([, q]) => !q || Number(q.trim().replace(/^q=/, '')) > 0).map(([c]) => c.trim().toLowerCase()));
      for (const [suffix, coding] of [['br', 'br'], ['gz', 'gzip']])
        if (accepted.has(coding) && existsSync(`${path}.${suffix}`))
          { const data = readFileSync(`${path}.${suffix}`); served[coding]++; return send(200, data, type, { 'Content-Encoding': coding, Vary: 'Accept-Encoding' }); }
    }
    const data = readFileSync(path); served.plain++;
    return send(200, data, type);
  };
  // Only this machine's page: a rebound host name never reaches the mounts.
  const port = server.address().port;
  if (req.headers.host === `localhost:${port}`) {   // another origin, with other storage: one address for the saves
    res.writeHead(302, { ...headers, Location: `http://127.0.0.1:${port}${req.url}` }); res.end(); return;
  }
  if (req.headers.host !== `127.0.0.1:${port}`) return send(403);
  try {
    if (req.method === 'GET' && (url.pathname === '/web/config.json' || url.pathname === '/config')) {   // the page's config.json (before the /web/ files)
      if (steps && !stepsStarted) { stepsStarted = true; runSteps().catch(e => say(`web_run.mjs: steps: ${e}\n`)); }
      return send(200, JSON.stringify({ runner: true, program: '/program.wasm', args: [argv0, ...args], env: guestEnv, canvas, frameBytes: 32 << 20,
                                        interactive, autostart: answer !== null, ...(answer === null ? {} : { answer }), report: metricsFile !== null, originalWindow,
                                        mounts: mounts.map(m => ({ guest: m.guest, writable: m.writable, ...(m.persist ? { persist: true } : {}) })) }), 'application/json');
    }
    if (req.method === 'GET' && url.pathname.startsWith('/web/')) {
      const name = url.pathname.slice(5);
      if (!/^[\w.-]+$/.test(name)) return send(404);
      const file = join(here, 'web', name);
      return existsSync(file) ? send(200, readFileSync(file), types[name.slice(name.lastIndexOf('.'))] ?? 'application/octet-stream') : send(404);
    }
    if (req.method === 'GET' && url.pathname === '/program.wasm') return file(program, types['.wasm']);
    const m = url.pathname.match(/^\/m\/(\d+)\/?(.*)$/);
    if (m) {
      const mount = mounts[Number(m[1])]; if (!mount || mount.persist) return send(404);   // a kept mount is the page's
      const rel = m[2].split('/').map(decodeURIComponent).join('/');
      const path = hostPath(mount, rel); if (!path) return send(403);
      if (req.method === 'GET') {
        if (!existsSync(path)) return send(404);
        const st = statSync(path);
        if (url.searchParams.has('list')) {
          if (!st.isDirectory()) return send(404);
          const names = readdirSync(path);
          // --precompressed: a file's .br/.gz forms are its encodings, not files of the folder.
          const form = name => precompressed && !mount.writable && /\.(br|gz)$/.test(name) && names.includes(name.slice(0, -3));
          const entries = names.filter(name => !form(name)).flatMap(name => {
            try { const s = statSync(join(path, name)); return [{ n: name, d: s.isDirectory(), s: s.isDirectory() ? 0 : s.size }]; }
            catch { return []; }   // a dangling link: not listed, as stat would fail in the guest too
          });
          return send(200, JSON.stringify(entries), 'application/json');
        }
        return st.isFile() ? file(path, 'application/octet-stream', !mount.writable) : send(404);
      }
      if (!mount.writable) return send(403);
      if (req.method === 'PUT') { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, await body(req)); return send(200); }
      if (req.method === 'POST') {
        const op = url.searchParams.get('op');
        if (op === 'mkdir') mkdirSync(path, { recursive: true });
        else if (op === 'unlink') { if (existsSync(path)) unlinkSync(path); }   // a file only the guest had seen
        else if (op === 'rmdir') rmdirSync(path);
        else if (op === 'rename') {
          const to = hostPath(mount, url.searchParams.get('to') ?? ''); if (!to) return send(403);
          mkdirSync(dirname(to), { recursive: true }); renameSync(path, to);
        } else return send(400);
        return send(200);
      }
      return send(405);
    }
    if (req.method === 'POST' && url.pathname === '/stdout') { await out(1, await body(req)); return send(200); }
    if (req.method === 'POST' && url.pathname === '/stderr') { await out(2, await body(req)); return send(200); }
    if (req.method === 'POST' && url.pathname === '/alive') { alive = Date.now(); return send(200); }
    if (req.method === 'POST' && url.pathname === '/page') {
      const data = await body(req); if (metricsFile) writeFileSync(join(dirname(metricsFile), 'page.json'), data); return send(200);
    }
    if (req.method === 'POST' && url.pathname === '/canvas') {
      const data = await body(req); if (metricsFile) writeFileSync(join(dirname(metricsFile), 'canvas-last.png'), data); return send(200);
    }
    if (req.method === 'POST' && url.pathname === '/metrics') {
      const data = await body(req);
      // With --precompressed, how the runner served the program and mounts' files (a run's own proof of the encodings).
      if (metricsFile) {
        let report = data;
        if (precompressed) try { report = JSON.stringify({ ...JSON.parse(data), served }); }
        catch { say('web_run.mjs: the worker\'s metrics did not parse; written without the served counts\n'); }
        writeFileSync(metricsFile, report);
      }
      return send(200);
    }
    if (req.method === 'POST' && url.pathname === '/exit') {
      if (serve !== null) { send(200); say(`web_run.mjs: the game ended (code ${url.searchParams.get('code')}); reload the page to play again\n`); return; }
      send(200); setTimeout(() => finish(Number(url.searchParams.get('code') ?? 1)), 10); return;
    }
    send(404);
  } catch (e) { say(`web_run.mjs: ${req.method} ${req.url}: ${e}\n`); send(500, String(e)); }
});

const engine = env.NTSD_BROWSER_ENGINE ?? 'chromium';
if (!['chromium', 'webkit'].includes(engine)) { console.error(`web_run.mjs: unknown NTSD_BROWSER_ENGINE ${engine}`); exit(2); }
// The newest WebKit build in Playwright's cache (its Playwright.app needs its
// frameworks on the dyld paths, as Playwright's pw_run.sh sets them).
function webkitFolder() {
  const cache = join(homedir(), 'Library/Caches/ms-playwright');
  const builds = existsSync(cache) ? readdirSync(cache).filter(d => /^webkit-\d+$/.test(d))
    .sort((a, b) => Number(a.split('-')[1]) - Number(b.split('-')[1])) : [];
  const last = builds.reverse().map(d => join(cache, d)).find(d => existsSync(join(d, 'Playwright.app')));
  if (!last) { console.error('web_run.mjs: no WebKit in the Playwright cache'); exit(2); }
  return last;
}
// --steps: the DevTools protocol over the headless shell's debugging port
// (Node's built-in WebSocket), from the moment the page asked for its config.
let stepsStarted = false;
async function runSteps() {
  const portFile = join(profile, 'DevToolsActivePort');
  for (let i = 0; i < 100 && !existsSync(portFile); i++) await new Promise(ok => setTimeout(ok, 100));
  const debugPort = readFileSync(portFile, 'utf8').split('\n')[0];
  const targets = await (await fetch(`http://127.0.0.1:${debugPort}/json/list`)).json();
  const target = targets.find(t => t.type === 'page' && (external ? t.url.startsWith(external.split('?')[0]) : t.url.includes('/web/run.html')));
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((ok, no) => { socket.onopen = ok; socket.onerror = no; });
  let next = 1; const pending = new Map();
  const call = (method, params = {}) => new Promise(ok => { const id = next++; pending.set(id, ok); socket.send(JSON.stringify({ id, method, params })); });
  // The worker's session, once attached (profiles; an external page's console).
  let worker = null;
  const profiling = steps.some(step => step.profile === 'start');
  const callWorker = (method, params = {}) => new Promise(ok => {
    const id = next++; pending.set(id, ok); socket.send(JSON.stringify({ id, sessionId: worker, method, params }));
  });
  socket.onmessage = ({ data }) => {
    const m = JSON.parse(data);
    if (pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
    if (m.method === 'Page.javascriptDialogOpening') {
      say(`web_run.mjs: the page asked ${JSON.stringify(m.params.message)}, accepted\n`); call('Page.handleJavaScriptDialog', { accept: true });
    }
    // An external page's output is the console's: the worker's, printed here.
    if (m.method === 'Target.attachedToTarget' && m.params.targetInfo.type === 'worker') {
      worker = m.params.sessionId;
      if (external) socket.send(JSON.stringify({ id: next++, sessionId: worker, method: 'Runtime.enable' }));
      // Sampled every 1 ms (V8's and node --cpu-prof's default, set explicitly); the
      // worker usually exists before this attach, so its first moments go unsampled.
      if (profiling) callWorker('Profiler.enable').then(() => callWorker('Profiler.setSamplingInterval', { interval: 1000 }))
        .then(() => callWorker('Profiler.start'));
    }
    if (m.method === 'Runtime.consoleAPICalled' && m.sessionId)
      say(`web_run.mjs: console ${m.params.args.map(a => a.value ?? a.description ?? '').join(' ').slice(0, 4000)}\n`);
  };
  await call('Page.enable');
  if (external || profiling) await call('Target.setAutoAttach', { autoAttach: true, waitForDebuggerOnStart: false, flatten: true });
  const evaluate = async expression => (await call('Runtime.evaluate', { expression, returnByValue: true })).result?.result?.value;
  const started = Date.now();
  for (const step of steps) {
    const wait = step.at * 1000 - (Date.now() - started); if (wait > 0) await new Promise(ok => setTimeout(ok, wait));
    if (step.key) {
      for (const type of ['keyDown', 'keyUp']) {
        if (type === 'keyUp') await new Promise(ok => setTimeout(ok, 120));
        await call('Input.dispatchKeyEvent', { type, code: step.key, key: step.key });
      }
    } else if (step.click) {
      const [x, y] = step.click;
      const at = await evaluate(`(() => { const c = document.querySelector('canvas'), r = c.getBoundingClientRect();
        return [r.left + (${x} + 0.5) * r.width / c.width, r.top + (${y} + 0.5) * r.height / c.height]; })()`);
      // Held for 120 ms, as a player's click is: the game reads the mouse once a tick.
      for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
        if (type === 'mouseReleased') await new Promise(ok => setTimeout(ok, 120));
        await call('Input.dispatchMouseEvent', { type, x: at[0], y: at[1], button: type === 'mouseMoved' ? 'none' : 'left', buttons: type === 'mousePressed' ? 1 : 0, clickCount: 1 });
      }
    } else if (step.chord) {   // keys pressed in order, held 120 ms, released in reverse (e.g. Alt+Enter)
      for (const code of step.chord) await call('Input.dispatchKeyEvent', { type: 'keyDown', code, key: code });
      await new Promise(ok => setTimeout(ok, 120));
      for (const code of [...step.chord].reverse()) await call('Input.dispatchKeyEvent', { type: 'keyUp', code, key: code });
    } else if (step.press) {
      const at = await evaluate(`(() => { const e = document.querySelector(${JSON.stringify(step.press)}); if (!e) return null;
        const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; })()`);
      if (!at) say(`web_run.mjs: no ${step.press} to press\n`);
      else for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased'])
        await call('Input.dispatchMouseEvent', { type, x: at[0], y: at[1], button: type === 'mouseMoved' ? 'none' : 'left', buttons: type === 'mousePressed' ? 1 : 0, clickCount: 1 });
    } else if (step.profile && step.profile !== 'start') {   // started when the worker attached
      const result = worker ? (await callWorker('Profiler.stop')).result : null;
      if (result && result.profile && metricsFile) writeFileSync(join(dirname(metricsFile), `${step.profile}.cpuprofile`), JSON.stringify(result.profile));
      else say(`web_run.mjs: no worker profile for ${step.profile}\n`);
    } else if (step.viewport) {
      const [width, height] = step.viewport;
      await call('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
    } else if (step.log) {
      say(`web_run.mjs: log ${step.log} = ${JSON.stringify(await evaluate(step.log))}\n`);
    } else if (step.capture && metricsFile) {
      const url = await evaluate(`document.querySelector('canvas').toDataURL('image/png')`);
      if (url) writeFileSync(join(dirname(metricsFile), `${step.capture}.png`), Buffer.from(url.split(',')[1], 'base64'));
    }
    say(`web_run.mjs: step ${JSON.stringify(step)}\n`);
  }
  // An external page reports nothing: its program's exit code, if it ended (W2b-4c).
  const ended = external ? await evaluate('self.ntsdPage ? self.ntsdPage.exit : undefined') : undefined;
  socket.close();
  if (external) finish(typeof ended === 'number' && ended !== 0 ? 1 : 0);
}

function browserPath() {
  if (env.NTSD_BROWSER) return env.NTSD_BROWSER;
  if (engine === 'webkit') return join(webkitFolder(), 'Playwright.app/Contents/MacOS/Playwright');
  const cache = join(homedir(), 'Library/Caches/ms-playwright');
  const shells = existsSync(cache) ? readdirSync(cache).filter(d => d.startsWith('chromium_headless_shell-'))
    .sort((a, b) => Number(a.split('-')[1]) - Number(b.split('-')[1])) : [];
  for (const d of shells.reverse()) {
    const p = join(cache, d, 'chrome-headless-shell-mac-arm64', 'chrome-headless-shell');
    if (existsSync(p)) return p;
  }
  console.error('web_run.mjs: no chrome-headless-shell in the Playwright cache; set NTSD_BROWSER'); exit(2);
}

server.on('error', e => { console.error(`web_run.mjs: ${e.message}`); exit(2); });   // e.g. the port is taken
server.listen(serve ?? port, '127.0.0.1', () => {
  if (serve !== null) { say(`web_run.mjs: open http://127.0.0.1:${server.address().port}/web/run.html\n`); return; }
  const { port } = server.address(), binary = browserPath();
  if (kept) { mkdirSync(kept, { recursive: true }); rmSync(join(kept, 'DevToolsActivePort'), { force: true }); }   // the last run's port is stale
  profile = kept ?? mkdtempSync(join(tmpdir(), 'ntsd-web-'));
  const page = external ?? `http://127.0.0.1:${port}/web/run.html`;
  if (external && steps && engine !== 'chromium') { console.error('web_run.mjs: --url with --steps needs Chromium (the DevTools protocol)'); exit(2); }
  if (external && holdFor !== null) setTimeout(() => finish(0), holdFor * 1000).unref();
  if (external && steps && !stepsStarted) { stepsStarted = true; runSteps().catch(e => { say(`web_run.mjs: steps: ${e}\n`); finish(1); }); }
  if (engine === 'webkit') {
    const frameworks = dirname(dirname(dirname(dirname(binary))));
    browser = spawn(binary, ['--headless', `--user-data-dir=${profile}`, page],
                    { stdio: ['ignore', 'ignore', 'pipe'], env: { ...env, DYLD_FRAMEWORK_PATH: frameworks, DYLD_LIBRARY_PATH: frameworks } });
  } else {
    // --remote-debugging-port keeps the headless shell running (on 127.0.0.1).
    // Automated runs have no player's gesture to start an AudioContext.
    browser = spawn(binary, ['--headless', '--no-first-run', '--disable-gpu', '--disable-extensions', '--autoplay-policy=no-user-gesture-required',
                             `--user-data-dir=${profile}`, '--remote-debugging-port=0', page], { stdio: ['ignore', 'ignore', 'pipe'] });
  }
  let log = '';
  browser.stderr.on('data', d => { log += d; if (log.length > 1 << 16) log = log.slice(-1 << 15); });
  browser.on('exit', code => {
    if (!finished) { say(`web_run.mjs: the browser exited (${code}) before the program\n${log.slice(-2000)}`); finish(134); }
  });
  // The page reports every 5 s while the worker runs: a crashed renderer, or
  // a page that never loads, goes quiet (120 s leaves room for throttled timers).
  alive = Date.now();
  if (!external) setInterval(() => {
    if (Date.now() - alive > 120_000) { say('web_run.mjs: the page stopped responding\n'); finish(134); }
  }, 5000).unref();
  // By default under run_headless_scenarios.py's 3600 s, so this process cleans up first.
  setTimeout(() => { say('web_run.mjs: timed out\n'); finish(124); }, timeout * 1000).unref();
});
