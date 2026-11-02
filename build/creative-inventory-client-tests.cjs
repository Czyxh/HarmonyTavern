const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/ChatPage.ets', 'utf8');
const start = source.indexOf('  private itemActionsAvailable()');
const end = source.indexOf('  @Builder\n  worldStateContent', start);
let calls = 0, finish, confirm;
const context = { exports: {}, NativeWorld: { itemAction: async () => {
  calls++;
  return await new Promise(resolve => { finish = resolve; });
} } };
vm.createContext(context);
vm.runInContext(ts.transpileModule('class Harness {\n' + source.slice(start, end) + '\n} exports.Harness = Harness;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, context);
function harness() {
  const instance = new context.exports.Harness();
  Object.assign(instance, { openChat: { character_name: 'role', file_name: 'chat' }, mounted: true, worldLoadRevision: 0,
    worldReport: { status: 'ready', state: { inventory: [{ name: '绷带', quantity: 2 }] } },
    getUIContext: () => ({ showAlertDialog: value => { confirm = value.secondaryButton.action; }, getPromptAction: () => ({ showToast() {} }) }) });
  return instance;
}
(async () => {
  const instance = harness();
  const job = instance.applyWorldItem(0, 'use');
  assert.equal(instance.itemActionsAvailable(), false);
  await instance.applyWorldItem(0, 'use'); assert.equal(calls, 1);
  finish({ status: 'ready', state: { inventory: [{ name: '绷带', quantity: 1 }] } }); await job;
  assert.equal(instance.worldReport.state.inventory[0].quantity, 1);
  assert.equal(instance.preparingGeneration, false); assert.equal(instance.worldItemBusy, false);
  instance.selectWorldItem(0, 'discard'); assert.equal(calls, 1);
  instance.worldReport = { status: 'ready', state: { inventory: [{ name: '其他物品' }] } };
  confirm(); assert.equal(calls, 1);
  instance.worldReport.status = 'stale'; await instance.applyWorldItem(0, 'discard'); assert.equal(calls, 1);
  instance.worldReport.status = 'ready'; const switched = instance.applyWorldItem(0, 'discard');
  instance.openChat = { character_name: 'other', file_name: 'other' };
  finish({ status: 'ready', state: { inventory: [] } }); await switched;
  assert.equal(instance.worldReport.state.inventory[0].name, '其他物品');
  const sidebar = fs.readFileSync('entry/src/main/ets/components/WorldJournalSidebar.ets', 'utf8');
  assert(!sidebar.includes('backgroundEffect')); assert(!sidebar.includes('NativeGlassBackdrop'));
  assert(sidebar.includes('journalMorph(this.frame())')); assert(!sidebar.includes('.scale('));
  assert(sidebar.includes('LiquidContour.body')); assert(sidebar.includes('this.panel.close()'));
  const page = fs.readFileSync('entry/src/main/ets/components/PageSurface.ets', 'utf8');
  assert(page.indexOf('RpgBackdrop()') < page.indexOf('if (this.scrollable)'));
  const dock = fs.readFileSync('entry/src/main/ets/components/WorldJournalDock.ets', 'utf8');
  assert(!dock.includes("id: 'inventory'")); assert(!dock.includes("id: 'status'")); assert(dock.includes("id: 'equipment'"));
  console.log('PASS: item action lock, stale guard, discard confirmation identity, conversation isolation; clear rounded content and background-only RPG decoration.');
})().catch(error => { console.error(error); process.exitCode = 1; });

