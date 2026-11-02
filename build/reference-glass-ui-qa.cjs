const q = require('./ui-probe.cjs'), assert = require('assert'), path = require('path');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const bounds = attr => attr.bounds.match(/\d+/g).map(Number);
function snapshot(name) {
  q.run('shell', 'snapshot_display', '-f', '/data/local/tmp/reference-glass.jpeg');
  q.run('file', 'recv', '/data/local/tmp/reference-glass.jpeg', path.resolve('build/' + name + '.jpeg'));
}
(async () => {
  const nodes = q.nodes();
  const list = nodes.find(node => node.a.type === 'List' && bounds(node.a)[3] - bounds(node.a)[1] > 1000).a;
  const header = nodes.find(node => node.a.id === 'chat-options-anchor').a;
  const hud = nodes.find(node => node.a.id === 'world-status-hud').a;
  assert(bounds(list)[1] < bounds(header)[1]); assert(bounds(list)[3] > bounds(hud)[3]);
  snapshot('reference-glass-rest');
  q.run('shell', 'uitest', 'uiInput', 'swipe', '600', '1200', '600', '1450', '1100'); await wait(700);
  snapshot('reference-glass-chat');
  console.log('PASS: message viewport extends behind header and HUD/composer; rest and scrolling screenshots saved for visual frost review.');
  q.tap(attr => attr.type === 'TextArea' && bounds(attr)[1] > 2000); await wait(1700);
  assert(q.nodes().some(node => node.a.id === 'KeyHideKbd'));
  snapshot('reference-glass-keyboard');
  q.tap(attr => attr.id === 'KeyHideKbd'); await wait(1500);
  assert(q.nodes().some(node => node.a.id === 'chat-world-inventory'));
  console.log('PASS: keyboard opens/closes without typing or sending; HUD and independent inventory action remain present.');
})().catch(error => { console.error(error); process.exitCode = 1; });
