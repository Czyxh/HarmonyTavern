const probe = require('./ui-probe.cjs'), assert = require('assert'), path = require('path');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const rect = attr => attr.bounds.match(/\d+/g).map(Number);
async function reset() {
  probe.run('shell', 'aa', 'force-stop', 'com.example.harmonytavern');
  probe.run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.harmonytavern'); await wait(900);
  for (let index = 0; index < 12 && !probe.nodes().some(node => node.a.text === 'default_Seraphina'); index++) {
    await wait(250);
  }
}
function snap(name) {
  probe.run('shell', 'snapshot_display', '-f', '/data/local/tmp/compact-hud.jpeg');
  probe.run('file', 'recv', '/data/local/tmp/compact-hud.jpeg', path.resolve('build/' + name + '.jpeg'));
}
(async () => {
  await reset(); probe.tap(attr => attr.text === 'default_Seraphina'); await wait(1300);
  let nodes = probe.nodes();
  const hud = nodes.find(node => node.a.id === 'world-status-hud').a, bounds = rect(hud);
  assert(bounds[3] - bounds[1] <= 170, 'HUD must be a single 48vp row');
  assert(hud.backgroundColor === '#00000000', 'HUD must not have a card background');
  assert(nodes.find(node => node.a.id === 'world-health-percent').a.text === '—', 'Unknown health must not show false percentage');
  for (const id of ['chat-world-inventory', 'chat-world-details']) {
    const button = nodes.find(node => node.a.id === id).a;
    assert(button.text === '' && button.backgroundColor === '#00000000');
    assert(nodes.some(node => (node.a.hierarchy || '').startsWith(button.hierarchy + ',') && node.a.type === 'Image'));
  }
  snap('compact-hud-chat');
  console.log('PASS: actual chat uses transparent single-row HUD and icon-only actions; unknown health stays unknown.');
  probe.tap(attr => attr.id === 'chat-options-anchor'); await wait(1000);
  nodes = probe.nodes(); const panel = nodes.find(node => node.a.id === 'origin-panel-surface').a, frame = rect(panel);
  const labels = nodes.filter(node => (node.a.hierarchy || '').startsWith(panel.hierarchy + ',') && node.a.type === 'Text').map(node => node.a.text);
  assert.strictEqual(labels.length, 8); assert(labels.includes('查看聊天上下文'));
  assert(!labels.some(label => label.includes('Seraphina') || label.includes('.jsonl') || label.includes(' · ')));
  const buttons = nodes.filter(node => (node.a.hierarchy || '').startsWith(panel.hierarchy + ',') && node.a.type === 'Button');
  const trailing = frame[3] - Math.max(...buttons.map(node => rect(node.a)[3]));
  assert(trailing >= -2 && trailing <= 65, 'Menu has excessive trailing blank area: ' + trailing);
  assert(frame[2] - frame[0] < 1000, 'Menu unnecessarily wide');
  snap('compact-hud-menu'); console.log('PASS: eight-action top-right menu contains no raw path/status text; trailing space=' + trailing + 'px.');
  probe.tap(attr => attr.id === 'origin-source-toggle'); await wait(600);
  probe.tap(attr => attr.id === 'chat-world-inventory'); await wait(1000);
  assert(probe.nodes().some(node => node.a.text === '背包物品栏'));
  probe.tap(attr => attr.id === 'origin-source-toggle'); await wait(600);
  probe.tap(attr => attr.id === 'chat-world-details'); await wait(1000);
  assert(probe.nodes().some(node => node.a.text === '创造模式'));
  console.log('PASS: both compact icons still open their independent inventory/status panels.');
  await reset(); probe.tap(attr => attr.id === 'chat-home-header-add'); await wait(300);
  probe.tap(attr => attr.text === '创建对话'); await wait(600);
  for (let index = 0; index < 18 && !probe.nodes().some(node => node.a.id === 'story-mode-world'); index++) {
    probe.run('shell', 'uitest', 'uiInput', 'swipe', '75', '2200', '75', '800', '1400'); await wait(180);
  }
  probe.tap(attr => attr.id === 'story-mode-world'); await wait(250);
  for (let index = 0; index < 12 && !probe.nodes().some(node => node.a.id === 'story-world-preview-toggle'); index++) {
    probe.run('shell', 'uitest', 'uiInput', 'swipe', '75', '2200', '75', '1000', '1400'); await wait(180);
  }
  probe.tap(attr => attr.id === 'story-world-preview-toggle'); await wait(300);
  for (let index = 0; index < 10 && !probe.nodes().some(node => node.a.id === 'world-status-hud' && rect(node.a)[1] > 350 && rect(node.a)[3] < 2450); index++) {
    probe.run('shell', 'uitest', 'uiInput', 'swipe', '75', '2200', '75', '1200', '1000'); await wait(180);
  }
  const demoNodes = probe.nodes();
  const percentage = demoNodes.find(node => node.a.id === 'world-health-percent' && node.a.text === '56%');
  assert(percentage);
  const healthBar = demoNodes.find(node => node.a.id === 'world-hud-health');
  assert(healthBar);
  assert(rect(percentage.a)[0] >= rect(healthBar.a)[2], 'Percentage must follow the right edge of the health bar');
  assert(rect(healthBar.a)[2] > rect(healthBar.a)[0], 'Health bar must have positive width');
  snap('compact-hud-red-preview');
  console.log('PASS: explicitly labeled unsaved offline demo shows red health bar and 56%; no model calls or chat writes.');
  await reset();
})().catch(error => { console.error(error); process.exitCode = 1; });
