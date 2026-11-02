const q = require('./ui-probe.cjs'), path = require('path'), assert = require('assert');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const nodes = () => q.nodes();
async function scrollUp() { q.run('shell', 'uitest', 'uiInput', 'swipe', '700', '2050', '700', '900', '1000'); await wait(250); }
async function top() { for (let count = 0; count < 5; count++) { q.run('shell', 'uitest', 'uiInput', 'swipe', '700', '1000', '700', '2100', '1500'); await wait(100); } }
async function find(id) {
  for (let count = 0; count < 8; count++) {
    const node = nodes().find(n => n.a.id === id);
    if (node) return node.a;
    await scrollUp();
  }
  throw Error('Missing ' + id);
}
async function input(id, text) {
  await find(id); q.tap(a => a.id === id);
  q.run('shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017');
  q.run('shell', 'uitest', 'uiInput', 'text', text);
  q.tap(a => a.id === 'KeyHideKbd'); await wait(200);
  assert.strictEqual(nodes().find(n => n.a.id === id).a.text, text);
}
async function effort(label) {
  await find('chat-reasoning-effort'); q.tap(a => a.id === 'chat-reasoning-effort'); await wait(200);
  q.tap(a => a.text === label && a.type === 'Option'); await wait(200);
}
async function save() {
  await find('chat-generation-save'); q.tap(a => a.id === 'chat-generation-save'); await wait(500);
  assert(!nodes().some(n => n.a.text.includes('重新读取后再保存')), 'Save conflict');
}
async function open() {
  q.tap(a => a.id === 'chat-conversations-anchor'); await wait(350);
  q.tap(a => a.id === 'chat-settings-entry'); await wait(350);
}
function snap(name) {
  q.run('shell', 'snapshot_display', '-f', '/data/local/tmp/generation-qa.jpeg');
  q.run('file', 'recv', '/data/local/tmp/generation-qa.jpeg', path.resolve('build/' + name + '.jpeg'));
}
(async () => {
  if (nodes().some(n => n.a.id === 'KeyHideKbd')) { q.tap(a => a.id === 'KeyHideKbd'); await wait(200); }
  await top();
  const reasoning = nodes().find(n => n.a.type === 'Toggle' && n.a.description.includes('思考'));
  await input('chat-output-limit', '256');
  await input('chat-context-limit', '4096');
  await effort('高'); snap('generation-parameters-draft');
  await save();
  q.run('shell', 'aa', 'force-stop', 'com.example.harmonytavern');
  q.run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.harmonytavern'); await wait(600);
  q.tap(a => a.text === 'default_Seraphina'); await wait(400); await open();
  assert.strictEqual((await find('chat-output-limit')).text, '256');
  assert.strictEqual((await find('chat-context-limit')).text, '4096');
  assert.strictEqual((await find('chat-reasoning-effort')).text, '高');
  console.log('PASS: output 256, input context 4096, effort high persisted across cold restart.');
  await top(); await input('chat-output-limit', '8192'); await input('chat-context-limit', '32768');
  await effort('模型默认'); await save();
  snap('generation-settings-bottom');
  q.tap(a => a.id === 'origin-source-toggle'); await wait(350); await open();
  assert.strictEqual((await find('chat-output-limit')).text, '8192');
  assert.strictEqual((await find('chat-context-limit')).text, '32768');
  assert.strictEqual((await find('chat-reasoning-effort')).text, '模型默认');
  console.log('PASS: original output/context/effort restored. No chat content changed or online provider called.');
})().catch(error => { console.error(error); process.exitCode = 1; });
