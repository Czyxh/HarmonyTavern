const fs = require('fs'), vm = require('vm'), assert = require('assert');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/ChatPage.ets', 'utf8');
const extract = (start, end) => source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start)));
const methods = extract('  private cancelContext()', '  private async resetContext()') + extract('  async send(', '  /** 起流');
let resolveGeneration, committed = 0, cancelled = 0, added = 0;
const context = {
  NativeContext: { prepare: async () => ({ expectedTurn: 'turn-1', dto: {}, covered: 6 }),
    commit: async () => { committed++; return { active: true, covered: 6 }; } },
  Backend: { generateChatCompletion: async () => new Promise(resolve => { resolveGeneration = resolve; }),
    cancelChatCompletionGeneration: async () => { cancelled++; }, addMessage: async () => { added++; } },
  DOMAIN: 2, TAG: 'test', hilog: { error() {} }, console
};
vm.createContext(context);
vm.runInContext(ts.transpileModule('class Harness {\n' + methods + '\n}\nglobalThis.Harness = Harness;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.None }
}).outputText, context);
const settle = async () => { for (let i = 0; i < 6; i++) await Promise.resolve(); };
function harness() {
  const h = new context.Harness();
  Object.assign(h, { openChat: { character_name: 'role', file_name: 'chat' }, mounted: true,
    contextRevision: 0, choicesRevision: 0, generationRevision: 0, contextApplying: false,
    inputText: 'Do not lose this input', chatPreferences: { trim_spaces: true }, story: { mode: 'free' }, messages: [] });
  h.loadCustomConfig = h.loadChatPreferences = async () => {};
  h.providerDto = () => ({});
  h.refreshStoryChoices = () => {};
  return h;
}
(async () => {
  const cancelledTask = harness();
  const pending = cancelledTask.compactContext();
  await settle(); assert(resolveGeneration, 'Model request not started');
  cancelledTask.cancelContext();
  resolveGeneration({ choices: [] }); await pending;
  assert.strictEqual(committed, 0); assert.strictEqual(cancelled, 1);
  assert.strictEqual(cancelledTask.preparingGeneration, false);
  console.log('PASS: cancelled compaction never applies late model result and releases generation lock.');
  const complete = harness();
  const job = complete.compactContext(); await settle(); resolveGeneration({ choices: [] }); await job;
  assert.strictEqual(committed, 1); assert.strictEqual(complete.contextInfo.covered, 6);
  assert.strictEqual(complete.contextBusy, false); assert.strictEqual(complete.contextApplying, false);
  console.log('PASS: successful compaction commits once and releases busy flags.');
  const sending = harness(); sending.buildDto = async () => { throw Error('Context budget exceeded'); };
  await sending.send();
  assert.strictEqual(added, 0); assert.strictEqual(sending.inputText, 'Do not lose this input');
  assert.strictEqual(sending.preparingGeneration, false);
  console.log('PASS: context-budget preflight fails before saving user message; input retained without duplicate history.');
  const dataSource = fs.readFileSync('entry/src/main/ets/components/ChatMessageSource.ets', 'utf8')
    .replace(/^import .*;\s*/m, '').replace('export interface ChatMessageRow', 'interface ChatMessageRow').replace('export class ChatMessageSource', 'class ChatMessageSource');
  vm.runInContext(ts.transpileModule(dataSource + '\nglobalThis.ChatMessageSource = ChatMessageSource;', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.None }
  }).outputText, context);
  const data = new context.ChatMessageSource(); let reloads = 0;
  const listener = { onDataReloaded() { reloads++; } };
  data.registerDataChangeListener(listener); data.registerDataChangeListener(listener);
  data.replace(Array.from({ length: 10000 }, (_, index) => ({ mes: String(index) })));
  assert.strictEqual(data.totalCount(), 10000); assert.strictEqual(reloads, 1);
  const key = data.getData(9999).key;
  data.replace(Array.from({ length: 10000 }, (_, index) => ({ mes: String(index) })));
  assert.notStrictEqual(data.getData(9999).key, key, 'Same-length edits must refresh lazy item');
  data.unregisterDataChangeListener(listener); data.replace([]);
  assert.strictEqual(reloads, 2); assert.strictEqual(data.totalCount(), 0);
  console.log('PASS: 10000-message lazy data source, listener deduplication/removal, same-length update invalidation.');
})().catch(error => { console.error(error); process.exitCode = 1; });
