#!/usr/bin/env node
// Runs a wasm32-unknown-wasip1 program under Node's WASI implementation: a test
// harness for the Web host's terminal stage (docs/research/TVOS_WEB.md W0/W1),
// as the Linux containers and Wine are for theirs.
//
// Usage: node wasi_run.mjs [--map GUEST=HOST ...] [--env KEY=VALUE ...]
//                          [--argv0 GUEST_PATH] -- PROGRAM.wasm [ARGS ...]
//
// Each --map preopens HOST as the guest directory GUEST. The environment is
// only what --env gives, plus TZ (from the caller's TZ, else Etc/GMT-1, the
// app_e2e zone). The program's stdout and stderr are this process's; its exit
// code is this process's exit code.
import { readFileSync } from 'node:fs';
import { WASI } from 'node:wasi';
import { argv, env, exit } from 'node:process';

const sep = argv.indexOf('--');
if (sep < 0 || sep + 1 >= argv.length) {
  console.error('usage: wasi_run.mjs [--map GUEST=HOST ...] [--env KEY=VALUE ...] [--argv0 PATH] -- PROGRAM.wasm [ARGS ...]');
  exit(2);
}
const options = argv.slice(2, sep);
const [program, ...args] = argv.slice(sep + 1);
const preopens = {};
const guestEnv = { TZ: env.TZ ?? 'Etc/GMT-1' };
let argv0 = program;
for (let i = 0; i < options.length; i += 2) {
  const [name, value] = [options[i], options[i + 1]];
  const at = value?.indexOf('=') ?? -1;
  if (name === '--map' && at > 0) preopens[value.slice(0, at)] = value.slice(at + 1);
  else if (name === '--env' && at > 0) guestEnv[value.slice(0, at)] = value.slice(at + 1);
  else if (name === '--argv0' && value) argv0 = value;
  else { console.error(`wasi_run.mjs: bad option ${name} ${value}`); exit(2); }
}
const wasi = new WASI({ version: 'preview1', args: [argv0, ...args], env: guestEnv, preopens, returnOnExit: true });
const module = await WebAssembly.compile(readFileSync(program));
const instance = await WebAssembly.instantiate(module, wasi.getImportObject());
exit(wasi.start(instance));
