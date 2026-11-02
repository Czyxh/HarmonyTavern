const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
function evaluate(source, context) {
  vm.createContext(context);
  vm.runInContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, context);
  return context;
}
function load(path, dependencies = {}) {
  return evaluate(fs.readFileSync(path, 'utf8'), { exports: {}, require: id => {
    assert(id in dependencies, 'Unexpected import ' + id);
    return dependencies[id];
  } }).exports;
}
const { StreamReveal } = load('entry/src/main/ets/theme/StreamReveal.ets');
for (const text of ['你好，故事开始了。', 'A😀B𠮷C', '文本'.repeat(3000)]) {
  let shown = 0;
  let frames = 0;
  while (shown < text.length) {
    const next = StreamReveal.boundary(text, shown, 16);
    assert(next > shown && next <= text.length);
    assert(!(next < text.length && /[\uD800-\uDBFF]/.test(text[next - 1])), 'Split surrogate pair');
    shown = next;
    assert(++frames < 45, 'Backlog must catch up within a bounded interval');
  }
}
const values = new Map();
const reading = load('entry/src/main/ets/theme/ReadingPreferences.ets', {
  './PersonalizationStore': { PersonalizationStore: { set: (key, value) => values.set(key, value) } }
});
reading.ReadingPreferences.reset();
assert.equal(values.get(reading.READING_LINE_KEY), 1.5);
assert.equal(values.get(reading.READING_INSET_KEY), 8);
reading.ReadingPreferences.setNumber(reading.READING_SIZE_KEY, 100);
assert.equal(values.get(reading.READING_SIZE_KEY), 22);
reading.ReadingPreferences.setNumber(reading.READING_LINE_KEY, NaN);
assert.equal(values.get(reading.READING_LINE_KEY), 1.5);
reading.ReadingPreferences.setNumber('lightSenseBlur', 0);
assert(!values.has('lightSenseBlur'));
const timers = new Map();
let timerId = 0;
let now = 0;
const streaming = fs.readFileSync('entry/src/main/ets/components/StreamingText.ets', 'utf8');
const streamingMethods = streaming.slice(streaming.indexOf('  aboutToAppear()'), streaming.indexOf('  build()'));
const streamContext = evaluate('class Harness {\n' + streamingMethods + '\n}\nglobalThis.Harness = Harness;', {
  StreamReveal, Date: { now: () => now },
  setTimeout: callback => { timers.set(++timerId, callback); return timerId; },
  clearTimeout: id => timers.delete(id)
});
const stream = new streamContext.Harness();
Object.assign(stream, { mounted: false, active: true, reduceMotion: false, displayed: '', text: '', timer: -1 });
stream.aboutToAppear();
stream.text = '😀第一段回复，保留每一个字。';
stream.targetChanged();
stream.text += '第二批追加的内容。';
stream.targetChanged();
assert.equal(timers.size, 1, 'Batches share one reveal timer');
while (timers.size) {
  const [id, callback] = timers.entries().next().value;
  timers.delete(id); now += 16; callback();
}
assert.equal(stream.displayed, stream.text);
stream.text += '停止前最后一个字。'; stream.targetChanged();
stream.active = false; stream.targetChanged();
assert.equal(stream.displayed, stream.text, 'Stop/error flushes all received text');
assert.equal(timers.size, 0);
stream.active = true; stream.text += '继续'; stream.targetChanged();
stream.aboutToDisappear();
assert.equal(timers.size, 0, 'Unmount cancels reveal work');
stream.mounted = true; stream.reduceMotion = true; stream.text += '减少动效'; stream.targetChanged();
assert.equal(stream.displayed, stream.text);
const chat = fs.readFileSync('entry/src/main/ets/pages/ChatPage.ets', 'utf8');
const visibleMethod = chat.slice(chat.indexOf('  private visibleStreamText()'), chat.indexOf('  private async loadChatPreferences()'));
const chatContext = evaluate('class Harness {\n' + visibleMethod + '\n}\nglobalThis.Harness = Harness;', {
  storyChoicesEnabled: story => story.choices_enabled || story.mode === 'choices'
});
const chatHarness = new chatContext.Harness();
chatHarness.story = { mode: 'world', choices_enabled: true };
for (const text of ['正文<story_options>[{}]', '正文<world_state>{}', '正文<story_opt', '正文<world_sta']) {
  chatHarness.streamText = text;
  assert.equal(chatHarness.visibleStreamText(), '正文');
}
chatHarness.story = { mode: 'free', choices_enabled: false };
chatHarness.streamText = '普通文本<story_options>';
assert.equal(chatHarness.visibleStreamText(), chatHarness.streamText);
const pending = [];
const frames = [];
const guide = fs.readFileSync('entry/src/main/ets/components/OnboardingGuide.ets', 'utf8');
const guideMethods = guide.slice(guide.indexOf('  aboutToAppear()'), guide.indexOf('  @Builder\n  headerActions()'));
const guideContext = evaluate('class Harness {\n' + guideMethods + '\n}\nglobalThis.Harness = Harness;', {
  GUIDE_STEPS: Array(5), Duration: { instant: 100 }, Curve: { EaseIn: 1 }, Spring: { enter: () => 1 },
  GuideFrame: class { constructor(action) { this.action = action; } }, Edge: { Top: 0 }
});
const guideHarness = new guideContext.Harness();
Object.assign(guideHarness, { step: 0, displayedStep: 0, revision: 0, reduceMotion: false });
guideHarness.guideScroller = { scrollEdge: () => {} };
guideHarness.getUIContext = () => ({
  animateTo: (options, action) => { action(); if (options.onFinish) pending.push(options.onFinish); },
  postFrameCallback: frame => frames.push(frame.action)
});
guideHarness.aboutToAppear();
guideHarness.moveTo(1); guideHarness.moveTo(2); guideHarness.moveTo(1);
while (pending.length) pending.shift()();
while (frames.length) frames.shift()();
assert.equal(guideHarness.step, 1);
assert.equal(guideHarness.displayedStep, 1);
assert.equal(guideHarness.contentOpacity, 1);
assert.equal(guideHarness.contentOffset, 0);
guideHarness.moveTo(4); guideHarness.reduceMotion = true; guideHarness.motionChanged();
while (pending.length) pending.shift()();
assert.equal(guideHarness.displayedStep, 4);
assert.equal(guideHarness.contentOpacity, 1);
guideHarness.moveTo(-100);
assert.equal(guideHarness.step, 0);
guideHarness.aboutToDisappear();
const holdingRules = fs.readFileSync('entry/src/main/ets/theme/HoldingPose.ets', 'utf8');
const holdingContext = evaluate(holdingRules.replace(/^import .*$/gm, '').replace(/export (const|class)/g, '$1')
  + '\nglobalThis.HoldingPose = HoldingPose;', {
  motion: { HoldingHandStatus: { NOT_HELD: 0, LEFT_HAND_HELD: 1, RIGHT_HAND_HELD: 2, BOTH_HANDS_HELD: 3, UNKNOWN_STATUS: 4 } },
  PersistentStorage: {}, AppStorage: {}, PersonalizationStore: {}, hilog: {}, canIUse: () => false
});
const pose = holdingContext.HoldingPose;
// Cup follows the holding hand; plus moves away from it; both hands: plus left, cup right.
assert.equal(pose.cupOnRight(2, false), true);
assert.equal(pose.cupOnRight(1, true), false);
assert.equal(pose.cupOnRight(3, false), true);
assert.equal(pose.actionOnRight(2, true), false);
assert.equal(pose.actionOnRight(1, false), true);
assert.equal(pose.actionOnRight(3, true), false);
assert.equal(pose.cupOnRight(4, true), true, 'unknown keeps the current side');
assert.equal(pose.actionOnRight(4, false), false, 'unknown keeps the current side');
for (const hand of [1, 2, 3]) {
  assert.notEqual(pose.cupOnRight(hand, true), pose.actionOnRight(hand, false), 'plus and cup never share a side');
}console.log('PASS: Unicode reveal, bounded catch-up, stop flush, timer lifecycle, reduced motion, reading bounds, independent metadata hiding, interruptible guide navigation.');

