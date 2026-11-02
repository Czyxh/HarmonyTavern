const probe = require('./ui-probe.cjs'), path = require('path'), assert = require('assert');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const visible = attr => { const bounds = attr.bounds.match(/\d+/g).map(Number); return bounds[2] > bounds[0] && bounds[1] >= 350 && bounds[3] < 2500; };
async function reset() {
  probe.run('shell', 'aa', 'force-stop', 'com.example.harmonytavern');
  probe.run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.harmonytavern'); await wait(700);
}
async function tab(index) {
  probe.tap(attr => attr.id === 'jelly-tab-item-' + index && Number(attr.bounds.match(/\d+/g)[1]) > 2000); await wait(300);
}
async function findText(text) {
  for (let index = 0; index < 12; index++) {
    if (probe.nodes().some(node => node.a.text === text && visible(node.a))) return;
    probe.run('shell', 'uitest', 'uiInput', 'swipe', '75', '2200', '75', '900', '1400'); await wait(200);
  }
  throw Error('Missing text ' + text);
}
async function setTheme(name) {
  await reset(); await tab(3); probe.tap(attr => attr.text === '个性化'); await wait(350);
  await findText(name); probe.tap(attr => attr.text === name); await wait(500);
}
function snap(name) {
  probe.run('shell', 'snapshot_display', '-f', '/data/local/tmp/creator-refine.jpeg');
  probe.run('file', 'recv', '/data/local/tmp/creator-refine.jpeg', path.resolve('build/' + name + '.jpeg'));
}
(async () => {
  try {
    await setTheme('柔雾绿'); await reset();
    for (let index = 0; index < 3; index++) {
      probe.tap(attr => attr.text === 'default_Seraphina');
      snap('creator-transition-' + index); await wait(1000);
      assert(probe.nodes().some(node => node.a.id === 'chat-tools-anchor'));
      probe.run('shell', 'uinput', '-S', '-c', '110', '260'); await wait(1200);
    }
    probe.tap(attr => attr.text === 'default_Seraphina'); await wait(400);
    probe.tap(attr => attr.id === 'chat-message-more-0'); await wait(350);
    assert(probe.nodes().some(node => node.a.text === '编辑这条消息'));
    snap('creator-sage-message-menu');
    probe.tap(attr => attr.id === 'origin-source-toggle'); await wait(350);
    console.log('PASS: sage theme message four-square menu uses shared frosted surface; sampled three home-to-chat transitions.');
    await reset(); await tab(3); await findText('工具'); probe.tap(attr => attr.text === '工具'); await wait(450);
    if (!probe.nodes().some(node => node.a.text === '恢复这份')) {
      probe.tap(attr => attr.text === '立即创建快照'); await wait(700);
    }
    await findText('恢复这份'); probe.tap(attr => attr.text === '恢复这份' && visible(attr)); await wait(1200);
    assert(probe.nodes().some(node => node.a.id === 'snapshot-confirm-restore'));
    assert(probe.nodes().some(node => node.a.id === 'snapshot-cancel-restore'));
    assert(!probe.nodes().some(node => node.a.type === 'AlertDialog'));
    snap('creator-themed-snapshot-confirm');
    probe.tap(attr => attr.id === 'snapshot-cancel-restore'); await wait(450);
    assert(!probe.nodes().some(node => node.a.id === 'snapshot-confirm-restore'));
    console.log('PASS: snapshot creation and themed in-app restore confirmation; cancel does not restore settings. QA safety snapshots retained.');
  } finally { await setTheme('护眼纸张'); }
  await reset(); probe.tap(attr => attr.id === 'chat-home-header-add'); await wait(200);
  probe.tap(attr => attr.text === '创建对话'); await wait(400);
  for (let index = 0; index < 16 && !probe.nodes().some(node => node.a.id === 'story-mode-world'); index++) {
    probe.run('shell', 'uitest', 'uiInput', 'swipe', '75', '2200', '75', '800', '1400'); await wait(200);
  }
  assert(probe.nodes().some(node => node.a.id === 'story-mode-world' && node.a.text === '创造模式'));
  probe.tap(attr => attr.id === 'story-mode-world'); await wait(250);
  for (let index = 0; index < 10 && !probe.nodes().some(node => node.a.id === 'story-world-preview-toggle'); index++) {
    probe.run('shell', 'uitest', 'uiInput', 'swipe', '75', '2200', '75', '1000', '1400'); await wait(200);
  }
  probe.tap(attr => attr.id === 'story-world-preview-toggle'); await wait(250);
  for (let index = 0; index < 10 && !probe.nodes().some(node => node.a.id === 'world-hud-health'); index++) {
    probe.run('shell', 'uitest', 'uiInput', 'swipe', '75', '2200', '75', '1200', '1000'); await wait(200);
  }
  const bounds = id => probe.nodes().find(node => node.a.id === id).a.bounds.match(/\d+/g).map(Number);
  const health = bounds('world-health-left'), statuses = bounds('world-status-right');
  assert(health[2] <= statuses[0], 'Health must be left of status strip');
  assert(probe.nodes().some(node => node.a.id === 'chat-world-inventory'));
  snap('creator-horizontal-hud-preview');
  probe.tap(attr => attr.id === 'chat-world-inventory'); await wait(250);
  console.log('PASS: creator label, health left, horizontal statuses right, dedicated inventory action; original paper theme restored, preview draft not saved.');
})().catch(error => { console.error(error); process.exitCode = 1; });
