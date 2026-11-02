const probe = require('./ui-probe.cjs'), path = require('path'), assert = require('assert');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const rect = attr => attr.bounds.match(/\d+/g).map(Number);
async function reset() {
  probe.run('shell', 'aa', 'force-stop', 'com.example.harmonytavern');
  probe.run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.harmonytavern'); await wait(900);
}
function snap(name) {
  probe.run('shell', 'snapshot_display', '-f', '/data/local/tmp/panel-sizing.jpeg');
  probe.run('file', 'recv', '/data/local/tmp/panel-sizing.jpeg', path.resolve('build/' + name + '.jpeg'));
}
function surface() { return probe.nodes().find(node => node.a.id === 'origin-panel-surface').a; }
function fitted(label, maximum) {
  const panel = surface(), bounds = rect(panel);
  const descendants = probe.nodes().filter(node => (node.a.hierarchy || '').startsWith(panel.hierarchy + ',') &&
    ['Text', 'Button'].includes(node.a.type) && node.a.visible === 'true').map(node => rect(node.a))
    .filter(child => child[3] <= bounds[3] + 2 && child[1] >= bounds[1]);
  const gap = bounds[3] - Math.max(...descendants.map(child => child[3]));
  assert(gap >= -2 && gap <= 110, label + ' excessive bottom gap: ' + gap);
  const height = bounds[3] - bounds[1];
  assert(height < maximum, label + ' failed to shrink: ' + height);
  console.log('PASS: ' + label + ' height=' + height + 'px, bottom padding=' + gap + 'px; no unused panel-sized blank area.');
  return height;
}
(async () => {
  await reset(); probe.tap(attr => attr.text === 'default_Seraphina'); await wait(1100);
  probe.tap(attr => attr.id === 'chat-world-inventory'); await wait(1200);
  const inventoryHeight = fitted('inventory', 1750); snap('panel-sizing-inventory');
  const source = rect(probe.nodes().find(node => node.a.id === 'origin-source-toggle').a);
  const sourceX = String((source[0] + source[2]) >> 1), sourceY = String((source[1] + source[3]) >> 1);
  probe.run('shell', 'uinput', '-S', '-c', sourceX, sourceY);
  probe.run('shell', 'uinput', '-S', '-c', sourceX, sourceY); await wait(1100);
  assert(Math.abs(fitted('rapid reversal', 1750) - inventoryHeight) <= 4);
  probe.tap(attr => attr.id === 'origin-source-toggle'); await wait(600);
  probe.tap(attr => attr.id === 'chat-conversations-anchor'); await wait(1000);
  probe.tap(attr => attr.id === 'chat-settings-entry'); await wait(1100);
  const settings = surface(), settingsBounds = rect(settings);
  assert(settingsBounds[3] - settingsBounds[1] <= 2200);
  const scroll = probe.nodes().find(node => (node.a.hierarchy || '').startsWith(settings.hierarchy + ',') && node.a.type === 'Scroll');
  assert(scroll && scroll.a.scrollable === 'true', 'Long settings must remain scrollable');
  for (let index = 0; index < 5; index++) {
    probe.run('shell', 'uitest', 'uiInput', 'swipe', '80', '1900', '80', '800', '1300'); await wait(180);
  }
  snap('panel-sizing-long-settings');
  console.log('PASS: long generation settings remain viewport-bounded and scrollable after switching from another panel; no settings changed.');
  await reset(); probe.tap(attr => attr.id === 'jelly-tab-item-3' && rect(attr)[1] > 2000); await wait(300);
  for (let index = 0; index < 10 && !probe.nodes().some(node => node.a.text === '工具' && rect(node.a)[1] > 350 && rect(node.a)[3] < 2500); index++) {
    probe.run('shell', 'uitest', 'uiInput', 'swipe', '75', '2200', '75', '900', '1400'); await wait(180);
  }
  probe.tap(attr => attr.text === '工具'); await wait(600);
  probe.tap(attr => attr.text === '恢复这份' && rect(attr)[1] > 350 && rect(attr)[3] < 2500); await wait(1100);
  assert(probe.nodes().some(node => node.a.id === 'snapshot-confirm-restore'));
  fitted('snapshot confirmation', 1350); snap('panel-sizing-snapshot');
  probe.tap(attr => attr.id === 'snapshot-cancel-restore'); await wait(600);
  assert(!probe.nodes().some(node => node.a.id === 'snapshot-confirm-restore'));
  console.log('PASS: compact snapshot confirmation cancels normally without restoring settings.');
  await reset();
})().catch(error => { console.error(error); process.exitCode = 1; });
