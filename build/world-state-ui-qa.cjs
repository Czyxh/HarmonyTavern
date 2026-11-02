const q = require('./ui-probe.cjs'), path = require('path'), assert = require('assert');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const originalTap = q.tap;
q.tap = (predicate, ancestor = false) => originalTap(attr => attr.bounds !== '[0,0][0,0]' && predicate(attr), ancestor);
async function find(id) {
  for (let index = 0; index < 16; index++) {
    const snapshot = q.nodes();
    if (snapshot.some(node => node.a.id === 'KeyHideKbd')) {
      q.tap(attr => attr.id === 'KeyHideKbd'); await wait(1400); continue;
    }
    const node = snapshot.find(n => n.a.id === id && n.a.bounds !== '[0,0][0,0]');
    if (node) return node.a;
    q.run('shell', 'uitest', 'uiInput', 'swipe', '75', '2200', '75', '800', '1500'); await wait(300);
  }
  throw Error('Missing ' + id);
}
function snap(name) {
  q.run('shell', 'snapshot_display', '-f', '/data/local/tmp/world-mode-qa.jpeg');
  q.run('file', 'recv', '/data/local/tmp/world-mode-qa.jpeg', path.resolve('build/' + name + '.jpeg'));
}
async function textAt(predicate, text) {
  q.tap(predicate); q.run('shell', 'uitest', 'uiInput', 'text', text); await wait(1200);
  for (let attempt = 0; attempt < 12; attempt++) {
    await wait(200);
    if (q.nodes().some(node => node.a.id === 'KeyHideKbd')) { q.tap(a => a.id === 'KeyHideKbd'); await wait(1400); break; }
  }
}
(async () => {
  q.run('shell', 'aa', 'force-stop', 'com.example.harmonytavern');
  q.run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.harmonytavern'); await wait(650);
  q.tap(a => a.id === 'chat-home-header-add'); await wait(250); q.tap(a => a.text === '创建对话'); await wait(450);
  q.tap(a => a.id === 'story-character-default_Seraphina'); await wait(400);
  q.tap(a => a.id === 'story-world-picker'); await wait(350);
  await find('story-world-Eldoria'); q.tap(a => a.id === 'story-world-Eldoria'); await wait(400);
  for (let index = 0; index < 6 && !q.nodes().some(n => n.a.type === 'TextInput'); index++) {
    q.run('shell', 'uitest', 'uiInput', 'swipe', '25', '2100', '25', '1100', '1000'); await wait(200);
  }
  await textAt(a => a.type === 'TextInput', 'WorldUI-QA-20261101');
  await find('story-mode-world'); q.tap(a => a.id === 'story-mode-world'); await wait(250);
  await find('story-world-ui-request');
  await textAt(a => a.id === 'story-world-ui-request', '根据 Eldoria 设定追踪人物状态、负面效果、背包与具体位置；未知数据不要编造。');
  await find('story-save'); q.tap(a => a.id === 'story-save'); await wait(900);
  assert(q.nodes().some(n => n.a.id === 'world-status-hud'), 'World HUD not visible after creating world-mode chat');
  assert(!q.nodes().some(n => n.a.text.includes('45 / 80')), 'Offline demo must never be saved into real world state');
  snap('world-mode-chat-empty'); q.tap(a => a.id === 'chat-world-details'); await wait(450);
  assert(q.nodes().some(n => n.a.text === '资料：Eldoria'));
  assert(q.nodes().some(n => n.a.text.includes('根据 Eldoria 设定追踪人物状态')));
  assert(q.nodes().some(n => n.a.id === 'world-generate' && n.a.enabled === 'true'));
  assert(q.nodes().some(n => n.a.text.includes('尚未生成界面')));
  snap('world-mode-generation-panel');
  q.tap(a => a.id === 'origin-source-toggle'); await wait(350);
  q.run('shell', 'aa', 'force-stop', 'com.example.harmonytavern');
  q.run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.harmonytavern'); await wait(750);
  q.tap(a => a.text.includes('WorldUI-QA-20261101')); await wait(550);
  assert(q.nodes().some(n => n.a.id === 'world-status-hud'));
  q.tap(a => a.id === 'chat-world-details'); await wait(350);
  assert(q.nodes().some(n => n.a.text === '资料：Eldoria'));
  assert(q.nodes().some(n => n.a.text.includes('根据 Eldoria 设定追踪人物状态')));
  assert(!q.nodes().some(n => n.a.text.includes('Unknown command')));
  console.log('PASS: independent world-mode chat created with Eldoria and custom demand, HUD above chat dock, real backend status/prepare entry, settings survived cold restart.');
  console.log('PASS: demo values were not persisted as real state. No online model request. Cleanup required only for WorldUI-QA-20261101 test conversation.');
})().catch(error => { console.error(error); process.exitCode = 1; });
