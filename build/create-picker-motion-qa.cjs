const q = require('./ui-probe.cjs');
const path = require('path');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const assert = (condition, message) => { if (!condition) throw Error(message); };
const has = id => q.nodes().some(n => n.a.id === id);
function snap(name) {
  q.run('shell', 'snapshot_display', '-f', '/data/local/tmp/create-motion.jpeg');
  q.run('file', 'recv', '/data/local/tmp/create-motion.jpeg', path.resolve('build/' + name + '.jpeg'));
}
async function toggle(name, expanded) {
  q.tap(a => a.id === 'story-' + name + '-picker');
  await wait(300);
  assert(has('story-' + name + '-expanded') === expanded, name + ' unexpected expanded state');
}
(async () => {
  await toggle('character', false);
  await toggle('character', true);
  q.tap(a => a.id === 'story-character-default_Seraphina');
  await wait(300);
  assert(!has('story-character-expanded'), 'Character selection must close its list');
  await toggle('history', true);
  const history = q.nodes().find(n => n.a.id.startsWith('story-history-') &&
    !['story-history-picker', 'story-history-empty', 'story-history-expanded'].includes(n.a.id));
  assert(history, 'Expected existing history');
  q.tap(a => a.id === history.a.id);
  await wait(350);
  assert(!has('story-history-expanded'), 'History must close after successful read');
  await toggle('history', true);
  q.tap(a => a.id === 'story-history-empty');
  await wait(300);
  assert(!has('story-history-expanded'), 'Empty history must close its list');
  await toggle('world', true);
  q.tap(a => a.id === 'story-world-Eldoria');
  await wait(250);
  assert(q.nodes().some(n => n.a.id === 'story-world-Eldoria' && n.a.selected === 'true'), 'World book not selected');
  await toggle('world', false);
  await toggle('world', true);
  assert(q.nodes().some(n => n.a.id === 'story-world-Eldoria' && n.a.selected === 'true'), 'Reopening lost selection');
  snap('create-picker-motion-expanded');
  await toggle('world', false);
  const b = q.nodes().find(n => n.a.id === 'story-world-picker').a.bounds.match(/\d+/g).map(Number);
  for (let i = 0; i < 8; i++) {
    q.run('shell', 'uinput', '-S', '-c', String((b[0] + b[2]) >> 1), String((b[1] + b[3]) >> 1));
    await wait(35);
  }
  await wait(350);
  assert(!has('story-world-expanded'), 'Rapid reverse toggles ended in wrong state');
  console.log('PASS: three selectors open/close, selection auto-close, world-book selection retained, eight rapid reverse toggles. No draft saved.');
})().catch(error => { console.error(error); process.exitCode = 1; });
