const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const storage = new Map([['activeProviderId', 'chat-provider']]);
const writes = [], rotations = [];
const Backend = {
  readSecretState: async () => ({ api_key_custom: [{ id: 'chat-key', active: true }] }),
  writeSecret: async (...args) => { writes.push(args); return 'private-aux-key'; },
  rotateSecret: async (...args) => { rotations.push(args); }
};
const modules = { './Backend': { Backend } };
function load(name) {
  const context = { exports: {}, require: key => modules[key] || {}, JSON, Date, Error,
    AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) } };
  vm.createContext(context);
  vm.runInContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/backend/' + name + '.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, context);
  modules['./' + name] = context.exports;
  return context.exports;
}
const { ProviderSetup } = load('ProviderSetup');
const catalog = load('ProviderCatalog');
const builtin = load('BuiltinAssistant');
builtin.BuiltinAssistant.secretId = async () => 'builtin-key';
const { AuxiliaryModels: models } = load('AuxiliaryModels');
const { StoryAssistant: story } = load('StoryAssistant');
(async () => {
  const input = { messages: [{ role: 'system', content: 'preserve world schema' }], max_tokens: 2400,
    model: 'main', secret_id: 'main-key', custom_url: 'https://main.example', moonshot_endpoint: 'global',
    custom_include_body: 'unrelated main provider body' };
  const route = await models.route(input);
  assert.equal(route.model, 'Qwen/Qwen3.5-4B'); assert.equal(route.secret_id, 'builtin-key');
  assert.equal(route.messages, input.messages); assert.equal(route.max_tokens, 2400);
  assert.equal(route.moonshot_endpoint, undefined); assert.equal(input.model, 'main');
  assert.equal(route.custom_include_body, 'enable_thinking: false');
  const jsonRoute = await models.route(input, true);
  assert(jsonRoute.custom_include_body.includes('response_format: { type: json_object }'));
  assert(!route.custom_include_body.includes('response_format'));
  const provider = catalog.PROVIDERS.find(item => item.id === 'custom');
  catalog.ProviderPreferences.put({ id: 'custom', saved: true, url: 'https://aux.example/v1', model: 'own:model',
    protocol: 'claude_messages', secretId: 'chat-key', extra: '', models: ['own:model', 'second-model', ''] });
  let state = { api_key_custom: [{ id: 'chat-key', active: false, value: 'masked' }], api_key_siliconflow: [{ id: 'silicon-key', active: true }] };
  Backend.readSecretState = async () => state;
  const choices = models.choices(state);
  assert.equal(choices.length, 2);
  assert.equal(choices[0].model, 'own:model'); assert.equal(choices[0].providerId, 'custom');
  assert(!choices.some(item => item.model === ''));
  models.select(choices[0].id);
  assert.equal(storage.get('activeProviderId'), 'chat-provider');
  assert.equal(writes.length, 0); assert.equal(rotations.length, 0);
  assert.equal(models.selected().model, 'own:model');
  const custom = await models.route(input);
  assert.equal(custom.model, 'own:model'); assert.equal(custom.custom_api_format, 'claude_messages');
  assert.equal(custom.secret_id, 'chat-key'); assert.equal(custom.custom_include_body, undefined);
  assert.equal((await models.route(input, true)).custom_include_body, undefined);
  const config = catalog.ProviderPreferences.get(provider);
  catalog.ProviderPreferences.put({ ...config, url: 'https://edited.example/v1', protocol: 'openai_responses' });
  const changed = await models.route(input);
  assert.equal(changed.custom_url, 'https://edited.example/v1'); assert.equal(changed.custom_api_format, 'openai_responses');
  assert.equal(changed.model, 'own:model');
  assert.throws(() => models.select('provider:custom:invented-model'), /保存/);
  state = { ...state, api_key_custom: [] };
  assert.equal(models.choices(state).length, 0);
  await assert.rejects(() => models.route(input), /密钥已移除/);
  state = { ...state, api_key_custom: [{ id: 'chat-key', active: false }] };
  catalog.ProviderPreferences.put({ id: 'siliconflow', saved: true, url: '', model: 'qwen-small',
    protocol: 'openai_compat', secretId: 'silicon-key', extra: 'global', models: [] });
  const nativeChoice = models.choices(state).find(item => item.providerId === 'siliconflow');
  models.select(nativeChoice.id);
  const nativeRoute = await models.route(input);
  assert.equal(nativeRoute.chat_completion_source, 'siliconflow'); assert.equal(nativeRoute.secret_id, 'silicon-key');
  assert.equal(nativeRoute.siliconflow_endpoint, 'global'); assert.equal(nativeRoute.custom_url, undefined);
  assert.equal(storage.get('activeProviderId'), 'chat-provider'); assert.equal(writes.length, 0);
  storage.set('auxiliaryModels', JSON.stringify([{ id: 'legacy', label: 'Previous', url: 'https://legacy.example',
    model: 'legacy-model', protocol: 'openai_compat', secretId: 'legacy-secret' }]));
  models.select('legacy'); assert.equal((await models.route(input)).model, 'legacy-model');
  models.select('builtin');
  const draft = { title: '夜雨', scenario: '书店', style: '日常', author_note: '温和', opening_message: '晚上好' };
  assert.equal(story.result({ choices: [{ finish_reason: 'stop', message: { content: JSON.stringify({ ...draft, mode: 'world', world_books: ['invented'] }) } }] }).mode, undefined);
  for (const value of [null, {}, { ...draft, title: 1 }, { ...draft, title: 'x'.repeat(101) }]) {
    assert.throws(() => story.result({ output_text: JSON.stringify(value) }));
  }
  assert.throws(() => story.result({ choices: [{ finish_reason: 'length', message: { content: JSON.stringify(draft) } }] }), /完整/);
  assert.throws(() => story.request('', { name: '角色', first_mes: '' }, draft), /需求/);
  const setup = { url: 'https://service.example/v1', model: 'exact-model', protocol: 'openai_compat', key: 'private-pasted-key', note: '' };
  assert(!JSON.stringify(builtin.BuiltinAssistant.configurationRequest(setup)).includes(setup.key));
  assert.throws(() => builtin.BuiltinAssistant.result(setup, { output_text: JSON.stringify({ ...setup, model: 'invented' }) }), /改动/);
  const pageSource = fs.readFileSync('entry/src/main/ets/pages/StoryPage.ets', 'utf8');
  const pageMethods = pageSource.slice(pageSource.indexOf('  aboutToDisappear()'), pageSource.indexOf('  private async load()'));
  let resolveDraft, cancelled = 0, requests = 0, prompts = 0;
  const pageContext = { StoryAssistant: story, AuxiliaryModels: models,
    Backend: { generateChatCompletion: async () => { requests++; return new Promise(resolve => { resolveDraft = resolve; }); },
      cancelChatCompletionGeneration: async () => { cancelled++; } } };
  vm.createContext(pageContext);
  vm.runInContext(ts.transpileModule('class Page {\n' + pageMethods + '\n}\nglobalThis.Page=Page;', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText, pageContext);
  function page() {
    const instance = new pageContext.Page();
    Object.assign(instance, { alive: true, assistantRevision: 0, assistantRequest: '', characterName: 'role',
      fileName: '', selectedHistory: '', assistantRequirement: '雨夜初遇', characters: [{ name: 'role', first_mes: '' }],
      story: { ...draft, mode: 'free', world_books: ['existing'], choice_count: 3 },
      characterKey: character => character.name, getUIContext: () => ({ showAlertDialog: () => { prompts++; } }) });
    return instance;
  }
  const settle = async () => { for (let index = 0; index < 12; index++) await Promise.resolve(); };
  const late = page(), pending = late.generateDraft(); await settle(); late.cancelAssistant();
  resolveDraft({ output_text: JSON.stringify(draft) }); await pending;
  assert.equal(late.assistantDraft, null); assert.equal(cancelled, 1); assert.equal(late.assistantBusy, false);
  const success = page(), job = success.generateDraft(); await settle();
  resolveDraft({ output_text: JSON.stringify({ ...draft, title: 'Generated' }) }); await job;
  assert.equal(success.story.title, draft.title); assert.equal(success.assistantDraft.title, 'Generated');
  success.applyAssistantDraft(); assert.equal(success.story.title, 'Generated');
  assert.equal(success.story.mode, 'free'); assert.equal(success.story.world_books[0], 'existing');
  const left = page(), leaving = left.generateDraft(); await settle(); left.aboutToDisappear();
  resolveDraft({ output_text: JSON.stringify(draft) }); await leaving; assert.equal(left.assistantDraft, null);
  const before = requests, existing = page(); existing.selectedHistory = 'history'; await existing.generateDraft();
  assert.equal(requests, before); assert.equal(prompts, 0);
  console.log('PASS: story draft requires explicit apply, preserves mode/books, skips existing chats and ignores cancelled/unmounted results.');
  console.log('PASS: saved provider choices, deduplication, encoded model IDs, credential reuse, native/custom routes, live provider edits, deleted-key rejection, legacy preservation and task isolation (mock).');
})().catch(error => { console.error(error); process.exitCode = 1; });
