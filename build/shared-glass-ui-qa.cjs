const q = require('./ui-probe.cjs'), path = require('path'), assert = require('assert');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const rect = attr => attr.bounds.match(/\d+/g).map(Number);
function snap(name) {
  q.run('shell', 'snapshot_display', '-f', '/data/local/tmp/shared-glass.jpeg');
  q.run('file', 'recv', '/data/local/tmp/shared-glass.jpeg', path.resolve('build/' + name + '.jpeg'));
}
async function home() {
  q.run('shell', 'aa', 'force-stop', 'com.example.harmonytavern');
  q.run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.harmonytavern'); await wait(1300);
  for (let index = 0; index < 12 && !q.nodes().some(node => node.a.text === 'default_Seraphina'); index++) await wait(250);
}
async function openPage(text) {
  await home(); q.tap(attr => attr.id === 'jelly-tab-item-3' && rect(attr)[1] > 2000); await wait(500);
  for (let index = 0; index < 12 && !q.nodes().some(node => node.a.text === text && rect(node.a)[1] >= 350 && rect(node.a)[3] < 2500); index++) {
    q.run('shell', 'uitest', 'uiInput', 'swipe', '75', '2200', '75', '900', '1400'); await wait(250);
  }
  q.tap(attr => attr.text === text && rect(attr)[1] >= 350 && rect(attr)[3] < 2500); await wait(1000);
}
(async () => {
  let nodes = q.nodes(); const hud = nodes.find(node => node.a.id === 'world-status-hud').a;
  const input = nodes.find(node => node.a.type === 'TextArea').a;
  const density = (rect(hud)[3] - rect(hud)[1]) / 48;
  const gap = (rect(input)[1] - rect(hud)[3]) / density;
  assert(gap >= 0 && gap <= 16); snap('shared-glass-chat');
  console.log('PASS: HUD closer to composer; HUD-to-inner-input gap=' + gap.toFixed(1) + 'vp, including inner padding.');
  for (const [title, name] of [['工具', 'tools'], ['个性化', 'appearance']]) {
    await openPage(title);
    q.run('shell', 'uitest', 'uiInput', 'swipe', '75', '1800', '75', '1450', '1000'); await wait(700);
    assert(q.nodes().some(node => node.a.text === title && rect(node.a)[1] < 400));
    snap('shared-glass-' + name);
    console.log('PASS: ' + title + ' header remains clear above scrolling content; screenshot saved for shared frosted-header review.');
  }
  await home();
})().catch(error => { console.error(error); process.exitCode = 1; });
