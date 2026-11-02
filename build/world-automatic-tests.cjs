const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/ChatPage.ets', 'utf8');
function extract(start, end) { return source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start))); }
let failSave = false, updates = 0, routes = [], preparations = [];
const context = { exports: {}, NativeStory: { commit: async () => { if (failSave) throw Error('save failed'); return { chat: { messages: [] } }; } },
  AuxiliaryModels: { route: async (_dto, _json, model) => { routes.push(model); return {}; } },
  NativeWorld: { prepare: async (_character, _file, _dto, automatic) => { preparations.push(automatic); return { dto: {}, expectedTurn: 'turn' }; }, commit: async () => ({ status: 'ready' }) },
  Backend: { generateChatCompletion: async () => ({ choices: [] }) }, HoldingPose: { actionOnRight: hand => hand === 'left' } };
vm.createContext(context);
vm.runInContext(ts.transpileModule('class Harness {\n' + extract('  private async persistNarrativeReply()', '  /** 会话内检索') + extract('  private async generateWorld(', '  private async saveWorldModel(') + extract('  private journalOnRight()', '  private openWorldSidebar(') + '\n} exports.Harness = Harness;', { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText, context);
function harness(mode = 'auxiliary', complete = true) {
  const instance = new context.exports.Harness(); Object.assign(instance, { mounted: true, openChat: { character_name: 'role', file_name: 'file' }, streamText: '正文', streamUsageComplete: complete, story: { mode: 'world', world_update_mode: mode, world_model_id: 'provider:saved/model' }, chatPreferences: {}, worldRevision: 0, worldLoadRevision: 0, refreshStoryChoices() {}, async loadChatList() {} }); return instance;
}
(async () => {
  for (const [mode, complete, expected] of [['auxiliary', true, 1], ['manual', true, 0], ['inline', true, 0], ['auxiliary', false, 0]]) {
    updates = 0; const instance = harness(mode, complete); instance.generateWorld = async automatic => { assert.equal(automatic, true); updates++; }; await instance.persistNarrativeReply(); assert.equal(updates, expected);
  }
  failSave = true; const failed = harness(); failed.generateWorld = async () => { throw Error('should not run'); }; await failed.persistNarrativeReply(); assert.equal(failed.replyNeedsSave, true); failSave = false;
  const instance = harness(); await instance.generateWorld(true); assert.equal(routes.pop(), 'provider:saved/model'); assert.equal(preparations.pop(), true); assert.equal(instance.worldReport.status, 'ready');
  const gone = harness(); gone.mounted = false; const before = preparations.length; await gone.generateWorld(); assert.equal(preparations.length, before);
  instance.story.world_sidebar_side = 'left'; assert.equal(instance.journalOnRight(), false);
  instance.story.world_sidebar_side = 'right'; assert.equal(instance.journalOnRight(), true);
  instance.story.world_sidebar_side = 'auto'; instance.holdingEnabled = true; instance.holdingAction = true; instance.holdingHand = 'left'; assert.equal(instance.journalOnRight(), true);
  instance.holdingHand = 'right'; assert.equal(instance.journalOnRight(), false);
  console.log('PASS: automatic updates require complete saved narrative; manual/inline/partial/failure/unmounted guards, per-story route and sidebar hand override.');
})().catch(error => { console.error(error); process.exitCode = 1; });
