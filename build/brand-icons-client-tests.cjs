const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const context = { exports: {}, $r: name => name };
vm.createContext(context);
vm.runInContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/theme/BrandIcons.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, context);
const icons = context.exports.BrandIcons;
const cases = [
  ['deepseek-chat', 'deepseek'], ['deepseek-ai/DeepSeek-V3', 'deepseek'],
  ['anthropic/claude-sonnet-4', 'claude'], ['openrouter/anthropic/claude-3.7-sonnet:free', 'claude'],
  ['google/gemini-2.5-pro', 'gemini'], ['google/gemma-3-27b-it', 'gemma'],
  ['Qwen/Qwen3.5-4B', 'qwen'], ['qwq-32b', 'qwen'], ['qvq-max', 'qwen'],
  ['kimi-k2', 'kimi'], ['moonshot-v1-8k', 'kimi'], ['z-ai/glm-4.5', 'zhipu'],
  ['THUDM/chatglm3-6b', 'zhipu'], ['MiniMax-M2', 'minimax'], ['abab6.5s-chat', 'minimax'],
  ['x-ai/grok-4', 'grok'], ['cohere/command-r-plus', 'cohere'], ['doubao-pro-32k', 'doubao'],
  ['ernie-4.5', 'wenxin'], ['hunyuan-turbos-latest', 'hunyuan'], ['step-2-16k', 'stepfun'],
  ['mistralai/Mistral-Small-3.2', 'mistral'], ['codestral-latest', 'mistral'],
  ['01-ai/Yi-34B-Chat', 'yi'], ['Baichuan2-13B-Chat', 'baichuan'], ['sonar-pro', 'perplexity'],
  ['meta-llama/Llama-3.3-70B-Instruct', 'meta'], ['llama3.2:latest', 'meta'],
  ['gpt-4o', 'openai'], ['openai/gpt-oss-120b', 'openai'], ['o3-mini', 'openai'],
  ['text-embedding-3-small', 'openai'], ['  GPT-4.1  ', 'openai']
];
for (const [model, expected] of cases) {
  assert.equal(icons.model(model), expected, model);
  assert(fs.existsSync('entry/src/main/resources/base/media/' + icons.resource(expected).split('.').pop() + '.svg'));
}
for (const model of ['', 'custom-model', 'not-gpt-4o', 'myclaude', 'gptish', 'moonshotting', 'yield', 'stepwise', 'cohere-unknown', 'deployment-123']) {
  assert.equal(icons.model(model), '', model);
}
assert.equal(icons.provider('custom'), '');
assert.equal(icons.provider('openai_compat'), '');
assert.equal(icons.provider('claude_messages'), '');
assert.equal(icons.provider('siliconflow'), 'siliconcloud');
assert.equal(icons.model('Qwen/Qwen3.5-4B'), 'qwen');
assert.equal(icons.provider('makersuite'), 'gemini');
assert.equal(icons.provider('xai'), 'grok');
assert.equal(icons.resource('unknown'), 'app.media.icon_model');
assert.equal(icons.monochrome('openai'), true);
assert.equal(icons.monochrome('deepseek'), false);
assert.equal(icons.monochrome('gemini'), false);
for (const brand of ['kimi', 'yi']) {
  const base = fs.readFileSync('entry/src/main/resources/base/media/brand_' + brand + '.svg', 'utf8');
  const dark = fs.readFileSync('entry/src/main/resources/dark/media/brand_' + brand + '.svg', 'utf8');
  assert(!base.includes('currentColor'));
  assert(!dark.includes('currentColor'));
  assert(base.includes('#1F2329'));
  assert(dark.includes('#F1F3F5'));
  assert.equal(base.replaceAll('#1F2329', 'foreground'), dark.replaceAll('#F1F3F5', 'foreground'));
}
console.log('Brand icon checks passed: model aliases, provider identity, unknown models, assets and tint policy.');
