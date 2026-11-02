// Transpile the actual ArkTS methods (no copied implementation) for deterministic cursor/usage tests.
const fs = require('fs'), vm = require('vm'), assert = require('assert');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/ChatPage.ets', 'utf8');
const method = (start, end) => source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start)));
const methods = [
  method('  private appendStreamBatch(', '  private receiveUsage('),
  method('  private receiveUsage(', '  /** 游标轮询'),
  method('  private startPolling()', '  private stopPolling()'),
  method('  private usageCounter(', '  private messageReasoning(')
].join('\n');
const timers = [], batches = [], calls = [];
const context = {
  Backend: { readChatCompletionStreamDecoded: async (id, cursor, format) => {
    calls.push({ id, cursor, format });
    assert(batches.length, 'Unexpected read');
    return batches.shift();
  } },
  setTimeout: action => { timers.push(action); return timers.length; },
  POLL_INTERVAL_MS: 300, DOMAIN: 2, TAG: 'test', hilog: { info() {}, warn() {} },
  console
};
vm.createContext(context);
const js = ts.transpileModule('class Harness {\n' + methods + '\n}\nglobalThis.Harness = Harness;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.None }
}).outputText;
vm.runInContext(js, context);
function harness() {
  const h = new context.Harness();
  Object.assign(h, { pollRunning: false, streaming: true, mounted: true, streamId: 'test-stream',
    afterSeq: 0, streamText: '', streamFormat: 'claude_messages', streamUsageComplete: false,
    chatPreferences: { auto_scroll_chat_to_bottom: false }, followLatest: false, streamReasoning: '' });
  h.finalizeStream = async () => { h.finished = true; };
  h.finishStreamError = message => { h.failed = message; };
  return h;
}
(async () => {
  const h = harness();
  const first = Array.from({ length: 64 }, (_, index) => ({ type: 'chunk', seq: index + 1,
    parts: [{ kind: 'text', text: 'a' }, ...(index ? [] : [{ kind: 'usage', usage: { prompt_tokens: 100, completion_tokens: 0, total_tokens: 100 } }])] }));
  batches.push({ status: 'done', events: first });
  batches.push({ status: 'done', events: [
    { type: 'chunk', seq: 65, parts: [{ kind: 'text', text: 'b' }, { kind: 'reasoning', text: 'provider reasoning' }, { kind: 'usage', usage: { completion_tokens: 12 } }] },
    { type: 'done', seq: 66 }
  ] });
  h.startPolling();
  await timers.shift()();
  assert(!h.finished, 'Terminal status before last cursor batch must not finalize');
  assert.strictEqual(h.streamText.length, 64);
  await timers.shift()();
  assert.strictEqual(h.streamText, 'a'.repeat(64) + 'b');
  assert.strictEqual(h.streamUsage.total_tokens, 112);
  assert.strictEqual(h.streamReasoning, 'provider reasoning');
  assert.strictEqual(h.streamUsage.prompt_tokens, 100);
  assert.strictEqual(h.streamUsageComplete, true);
  assert(h.finished);
  assert.deepStrictEqual(calls.map(v => v.cursor), [0, 64]);
  assert.strictEqual(calls[0].format, 'claude_messages');
  console.log('PASS: terminal-status batching drains late text/usage; partial snapshots merge without duplicate addition.');
  const failed = harness();
  batches.push({ status: 'error', events: [{ type: 'chunk', seq: 1, parts: [{ kind: 'text', text: 'partial' }] },
    { type: 'error', seq: 2, message: 'test failure' }] });
  failed.startPolling(); await timers.shift()();
  assert(failed.failed); assert(!failed.streamUsageComplete); assert(!failed.finished);
  console.log('PASS: interrupted/error stream never marks reported usage as complete.');
  assert.strictEqual(h.messageUsageText({ extra: {} }), 'Token：未提供');
  assert.strictEqual(h.messageUsageText({ extra: { harmony_token_usage: { prompt_tokens: 100, completion_tokens: 0, total_tokens: 100 } } }),
    'Token · 输入 100 · 输出 0 · 合计 100');
  assert.strictEqual(h.messageUsageText({ extra: { harmony_token_usage: { completion_tokens: 9 }, harmony_usage_complete: false } }),
    'Token · 输入 未提供 · 输出 9 · 合计 未提供 · 未完整结束');
  assert.strictEqual(h.usageCounter(-1), '未提供');
  console.log('PASS: message labels distinguish known zero, missing, partial, negative and incomplete counts.');
})().catch(error => { console.error(error); process.exitCode = 1; });
