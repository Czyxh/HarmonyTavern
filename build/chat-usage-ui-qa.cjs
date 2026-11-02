const q = require('./ui-probe.cjs');
const path = require('path');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const assert = (condition, message) => { if (!condition) throw Error(message); };
function snap(name) {
  q.run('shell', 'snapshot_display', '-f', '/data/local/tmp/chat-usage.jpeg');
  q.run('file', 'recv', '/data/local/tmp/chat-usage.jpeg', path.resolve('build/' + name + '.jpeg'));
}
async function enterSettings() {
  q.tap(a => a.id === 'chat-conversations-anchor');
  await wait(400);
  assert(q.nodes().some(n => n.a.id === 'chat-settings-entry'), 'Settings missing from plus-one panel');
  q.tap(a => a.id === 'chat-settings-entry');
  await wait(300);
  assert(q.nodes().some(n => n.a.text === '聊天设置'), 'Settings panel title missing');
}
async function closeSettings() {
  q.tap(a => a.id === 'origin-source-toggle');
  await wait(400);
}
(async () => {
  await wait(500);
  q.tap(a => a.text === 'default_Seraphina');
  await wait(500);
  const original = q.nodes().some(n => n.a.id === 'chat-message-usage-0');
  console.log('Original usage display:', original);
  await enterSettings();
  let toggle = q.nodes().find(n => n.a.id === 'chat-token-usage-toggle').a;
  if (toggle.checked !== 'true') { q.tap(a => a.id === 'chat-token-usage-toggle'); await wait(250); }
  assert(q.nodes().some(n => n.a.id === 'chat-token-usage-toggle' && n.a.checked === 'true'), 'Usage toggle did not turn on');
  snap('chat-usage-settings');
  q.tap(a => a.id === 'chat-settings-back');
  await wait(250);
  assert(q.nodes().some(n => n.a.id === 'chat-settings-entry'), 'Back did not return to conversation list');
  q.tap(a => a.id === 'chat-settings-entry');
  await wait(250);
  await closeSettings();
  assert(q.nodes().some(n => n.a.id === 'chat-message-usage-0' && n.a.text === 'Token：未提供'), 'Old greeting must report missing usage, never zero');
  snap('chat-usage-unavailable');
  q.run('shell', 'aa', 'force-stop', 'com.example.harmonytavern');
  q.run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.harmonytavern');
  await wait(700);
  q.tap(a => a.text === 'default_Seraphina');
  await wait(450);
  assert(q.nodes().some(n => n.a.id === 'chat-message-usage-0'), 'Usage preference not persisted after restart');
  await enterSettings();
  assert(q.nodes().some(n => n.a.id === 'chat-token-usage-toggle' && n.a.checked === 'true'), 'Persisted toggle not on');
  if (!original) { q.tap(a => a.id === 'chat-token-usage-toggle'); await wait(250); }
  await closeSettings();
  assert(q.nodes().some(n => n.a.id === 'chat-message-usage-0') === original, 'Original usage visibility not restored');
  console.log('PASS: plus-one settings entry, back to conversations, enable, missing/legacy usage, cold-restart persistence, original preference restored. No chat content changed or provider requested.');
})().catch(error => { console.error(error); process.exitCode = 1; });
