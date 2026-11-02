import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const registry = read('tauritavern-ref/src-tauri/crates/tauritavern/src/presentation/commands/registry.rs');
const dispatch = read('native/crates/ttavern/src/presentation/dispatch.rs');
const names = [...new Set([...registry.matchAll(/super::\w+::(\w+)/g)].map(m => m[1]))];
const routes = new Set([...dispatch.matchAll(/"([a-z][a-z0-9_]+)"\s*(?:=>|\|)/g)].map(m => m[1]));
const unavailable = [...dispatch.matchAll(/commands::not_ported::\w+\(\s*"(\w+)"/g)].map(m => m[1]);
const aliases = {
  begin_world_info_commit: 'world_info_begin_commit',
  append_world_info_commit_chunk: 'world_info_append_commit_chunk',
  finish_world_info_commit: 'world_info_finish_commit',
  abort_world_info_commit: 'world_info_abort_commit'
};
const report = {
  baseline: 'Local TauriTavern reference snapshot; command-name comparison is not feature or current-main equivalence.',
  generatedAt: new Date().toISOString(),
  upstreamCommands: names.length,
  nativeRoutes: routes.size,
  identicalRouteNames: names.filter(n => routes.has(n)).length,
  explicitlyUnavailable: unavailable,
  aliases: Object.fromEntries(Object.entries(aliases).filter(([, v]) => routes.has(v))),
  absentNamesRequiringReview: names.filter(n => !routes.has(n) && !routes.has(aliases[n]))
};
fs.writeFileSync(path.join(root, 'docs/backend-parity-20261031.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
