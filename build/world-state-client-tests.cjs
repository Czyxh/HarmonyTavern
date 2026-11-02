const fs = require('fs'), vm = require('vm'), assert = require('assert');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/ChatPage.ets', 'utf8');
const extract = (start, end) => source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start)));
const methods = extract('  private async loadWorldStatus()', '  @Builder\n  worldStateContent') +
  extract('  private visibleStreamText()', '  private async loadChatPreferences()');
let resolveModel, rejectModel, commits = 0, cancelled = 0, prompts = 0;
const context = {
  AuxiliaryModels: { route: async input => ({ ...input, model: 'auxiliary-world-model', secret_id: 'auxiliary-secret' }) },
  NativeWorld: { prepare: async (_character, _file, dto) => {
    assert.strictEqual(dto.model, 'auxiliary-world-model'); assert.strictEqual(dto.secret_id, 'auxiliary-secret');
    return { expectedTurn: 'scene-1', dto };
  },
    commit: async () => { commits++; return { status: 'ready', state: { title: 'World' } }; } },
  Backend: { generateChatCompletion: async () => new Promise((resolve, reject) => { resolveModel = resolve; rejectModel = reject; }),
    cancelChatCompletionGeneration: async () => { cancelled++; } }
};
vm.createContext(context);
vm.runInContext(ts.transpileModule('class Harness {\n' + methods + '\n}\nglobalThis.Harness = Harness;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.None }
}).outputText, context);
const settle = async () => { for (let index = 0; index < 8; index++) await Promise.resolve(); };
function harness() {
  const instance = new context.Harness();
  Object.assign(instance, { openChat: { character_name: 'role', file_name: 'chat' }, mounted: true,
    worldRevision: 0, worldLoadRevision: 0, worldApplying: false, story: { mode: 'world' },
    worldReport: { status: 'missing' } });
  instance.loadCustomConfig = async () => {}; instance.providerDto = () => ({});
  instance.getUIContext = () => ({ showAlertDialog() { prompts++; } });
  return instance;
}
(async () => {
  const cancelledTask = harness(); const pending = cancelledTask.generateWorld(); await settle();
  cancelledTask.cancelWorld(); resolveModel({ choices: [] }); await pending;
  assert.strictEqual(commits, 0); assert.strictEqual(cancelled, 1); assert.strictEqual(cancelledTask.preparingGeneration, false);
  console.log('PASS: cancelled world UI request ignores late result, retains snapshot and releases generation lock.');
  const successful = harness(); const job = successful.generateWorld(); await settle(); resolveModel({ choices: [] }); await job;
  assert.strictEqual(commits, 1); assert.strictEqual(successful.worldReport.status, 'ready'); assert.strictEqual(successful.worldBusy, false);
  assert.strictEqual(successful.worldApplying, false);
  console.log('PASS: successful world UI request commits once and updates displayed report.');
  const switched = harness(); const old = switched.generateWorld(); await settle();
  switched.openChat = { character_name: 'other', file_name: 'other' }; resolveModel({ choices: [] }); await old;
  assert.strictEqual(commits, 1); assert.strictEqual(switched.worldReport.status, 'missing');
  console.log('PASS: switched conversation never applies foreign result.');
  const auth = harness(); const authorized = auth.generateWorld(); await settle(); auth.cancelWorld();
  rejectModel(Error('endpoint_authorization_required|https://example.test')); await authorized;
  assert.strictEqual(prompts, 0); assert.strictEqual(commits, 1);
  console.log('PASS: cancelled request cannot show late endpoint authorization dialog.');
  const scene = harness(); let firstStatus, secondStatus;
  context.NativeWorld.status = async () => new Promise(resolve => { if (!firstStatus) firstStatus = resolve; else secondStatus = resolve; });
  const first = scene.loadWorldStatus(); const second = scene.loadWorldStatus();
  secondStatus({ status: 'ready', message: 'new' }); await second; firstStatus({ status: 'ready', message: 'old' }); await first;
  assert.strictEqual(scene.worldReport.message, 'new');
  console.log('PASS: older status read cannot overwrite newer world snapshot.');
  scene.streamText = '正文<world_state>{"version":1}'; assert.strictEqual(scene.visibleStreamText(), '正文');
  scene.streamText = '正文<world_sta'; assert.strictEqual(scene.visibleStreamText(), '正文');
  scene.story.mode = 'free'; assert.strictEqual(scene.visibleStreamText(), '正文<world_sta');
  scene.story.mode = 'choices'; scene.streamText = '正文<story_options>[]'; assert.strictEqual(scene.visibleStreamText(), '正文');
  console.log('PASS: streaming JSON and partial protocol markers stay hidden; original free/choice behavior preserved.');
  const helperContext = { exports: {}, require: () => ({ Backend: {} }) }; vm.createContext(helperContext);
  vm.runInContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/backend/NativeWorld.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, helperContext);
  const api = helperContext.exports;
  assert.strictEqual(api.worldNeedsInitialization({ status: 'missing' }), true);
  for (const status of ['loading', 'ready', 'stale', 'error']) {
    assert.strictEqual(api.worldNeedsInitialization({ status, state: { title: 'initialized' } }), false);
  }
  for (const status of ['loading', 'error', 'disabled']) assert.strictEqual(api.worldNeedsInitialization({ status }), false);
  const retained = harness(); retained.worldReportKey = 'role/chat'; retained.worldReport = { status: 'ready', state: { title: 'saved' } };
  context.NativeWorld.status = async () => { throw Error('offline'); };
  const refreshing = retained.loadWorldStatus(); assert.strictEqual(retained.worldReport.state.title, 'saved');
  await refreshing; assert.strictEqual(retained.worldReport.status, 'stale'); assert.strictEqual(retained.worldReport.state.title, 'saved');
  retained.openChat = { character_name: 'other', file_name: 'other' }; await retained.loadWorldStatus();
  assert.strictEqual(retained.worldReport.state, undefined);
  console.log('PASS: initialized hints stay hidden during refresh/error, and retained snapshots never cross conversations.');
  assert.strictEqual(api.worldMeterLabel({ value: null, unit: '' }), '未确认');
  assert.strictEqual(api.worldMeterLabel({ value: 0, max: 80, unit: '' }), '0 / 80');
  assert.strictEqual(api.worldMeterLabel({ value: 45, max: 80, unit: '' }), '45 / 80');
  assert.strictEqual(api.worldMeterPercent({ value: 45, max: 80 }), 56.25);
  assert.strictEqual(api.worldLocationLabel({ region: '', place: '', detail: '' }), '位置未确认');
  console.log('PASS: unknown versus known zero, actual bar ratios and unknown locations remain distinguishable.');
})().catch(error => { console.error(error); process.exitCode = 1; });
