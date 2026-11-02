const fs = require('fs'), vm = require('vm'), assert = require('assert');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const ctx = { exports: {}, JSON, Error, Date, AppStorage: { get: () => undefined } };
vm.createContext(ctx);
const transpile = code => '(function(){' + ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText + '\n})();';
vm.runInContext(transpile(fs.readFileSync('entry/src/main/ets/backend/ProviderSetup.ets', 'utf8')), ctx);
const parser = ctx.exports.ProviderSetup;
const draft = parser.parse(`curl https://example.com/v1/chat/completions -H 'Authorization: Bearer sk-private-test' -d '{"model":"test-model"}'`);
assert.equal(draft.url, 'https://example.com/v1'); assert.equal(draft.model, 'test-model'); assert.equal(draft.key, 'sk-private-test');
assert(!parser.prompt(draft).includes(draft.key)); assert.equal(Object.keys(JSON.parse(parser.prompt(draft))).sort().join(','), 'model,protocol,url');
for (const url of ['https://key@example.com/v1', 'https://example.com/v1?key=private', 'https://example.com/#secret', 'file:///private', 'https://example.com/ white']) {
  assert.throws(() => parser.prompt({ ...draft, url }));
}
assert.equal(parser.parse('https://example.com/v1/responses').protocol, 'openai_responses');
assert.equal(parser.parse('https://example.com/v1/messages').protocol, 'claude_messages');
assert.throws(() => parser.validate({ ...draft, protocol: 'untrusted' }));
for (const response of [{ choices: [{ message: { content: 'yes' } }] }, { content: [{ type: 'text', text: 'yes' }] },
  { output: [{ content: [{ text: 'yes' }] }] }, { candidates: [{ content: { parts: [{ text: 'yes' }] } }] }]) {
  assert.equal(parser.responseText(response), 'yes');
}
const calls = [];
ctx.Backend = {
  generateChatCompletion: async (id, dto) => {
    calls.push({ id, dto });
    return { choices: [{ message: { content: JSON.stringify({ url: draft.url, model: draft.model, protocol: 'openai_responses' }) } }] };
  },
  readSecretState: async () => ({ api_key_custom: [{ id: 'assistant-secret', active: false, label: 'HarmonyTavern 内置配置助手 · SiliconFlow' }] })
};
ctx.require = name => name === './Backend' ? { Backend: ctx.Backend } : name === './ProviderSetup' ? { ProviderSetup: parser } :
  name === './ProviderCatalog' ? {} :
  name === './BuiltinAssistant' ? { BuiltinAssistant: ctx.BuiltinAssistant, BUILTIN_ASSISTANT_MODEL: 'Qwen/Qwen3.5-4B', BUILTIN_ASSISTANT_URL: 'https://api.siliconflow.cn/v1' } : {};
vm.runInContext(transpile(fs.readFileSync('entry/src/main/ets/backend/BuiltinAssistant.ets', 'utf8')), ctx);
ctx.BuiltinAssistant = ctx.exports.BuiltinAssistant;
vm.runInContext(transpile(fs.readFileSync('entry/src/main/ets/backend/AuxiliaryModels.ets', 'utf8')), ctx);
ctx.AuxiliaryModels = ctx.exports.AuxiliaryModels;
const source = fs.readFileSync('entry/src/main/ets/pages/SettingsPage.ets', 'utf8');
const methods = source.slice(source.indexOf('  private async assistConfiguration('), source.indexOf('  async testConnection('));
vm.runInContext(transpile('class Assistant {\n' + methods + '\n}\nglobalThis.Assistant=Assistant;'), ctx);
(async () => {
  const assistant = new ctx.Assistant(); assistant.readOnly = false; assistant.callWithEndpointAuth = operation => operation();
  const result = await assistant.assistConfiguration(draft);
  assert.equal(result.key, draft.key); assert.equal(result.protocol, 'openai_responses');
  assert(!JSON.stringify(calls).includes(draft.key)); assert(calls[0].id.startsWith('provider_setup_'));
  assert.equal(calls[0].dto.model, 'Qwen/Qwen3.5-4B'); assert.equal(calls[0].dto.secret_id, 'assistant-secret');
  ctx.Backend.generateChatCompletion = async () => ({ output_text: '{"url":"https://invented.example","model":"invented","protocol":"openai_compat"}' });
  await assert.rejects(() => assistant.assistConfiguration(draft), /改动/);
  assistant.readOnly = true; await assert.rejects(() => assistant.assistConfiguration(draft), /停止/);
  const writes = [], rotations = [];
  ctx.Backend.readSecretState = async () => ({ api_key_custom: [{ id: 'chat-key', active: true, label: 'Chat provider' }] });
  ctx.Backend.writeSecret = async (...args) => { writes.push(args); return 'new-assistant-id'; };
  ctx.Backend.rotateSecret = async (...args) => { rotations.push(args); };
  await ctx.BuiltinAssistant.saveKey('sk-fixture');
  assert.equal(writes[0][0], 'api_key_custom'); assert.equal(rotations[0][1], 'chat-key');
  assert.throws(() => ctx.BuiltinAssistant.request(draft, ''), /选择已配置的服务商模型/);
  console.log('PASS: local parsing, secret allowlist, selected auxiliary route, explicit assistant secret, preserving chat credential, response validation and read-only guard (mock).');
})().catch(error => { console.error(error); process.exitCode = 1; });
