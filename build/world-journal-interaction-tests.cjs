const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const source = fs.readFileSync('entry/src/main/ets/components/WorldJournalDock.ets', 'utf8');
const methods = source.slice(source.indexOf('  private motionChanged()'), source.indexOf('  build()'));
const context = { exports: {}, Curve: { EaseInOut: 1 } }; vm.createContext(context);
vm.runInContext(ts.transpileModule('class Harness {\n' + methods + '\n} exports.Harness = Harness;', { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText, context);
const dock = new context.exports.Harness(); const durations = [];
Object.assign(dock, { expanded: false, railVisible: false, revision: 0, progress: 0, onRight: true, dockRight: true, topInset: 24, bottomInset: 24, windowHeight: 800,
  getUIContext: () => ({ animateTo(options, update) { durations.push(options.duration); update(); if (options.onFinish) options.onFinish(); } }) });
dock.toggle(); assert.equal(dock.progress, 1); assert.equal(dock.right(), true);
dock.onRight = false; assert.equal(dock.right(), true);
dock.toggle(); assert.equal(dock.progress, 0); assert.equal(dock.railVisible, false); dock.toggle(); assert.equal(dock.right(), false);
for (let count = 0; count < 5; count++) dock.toggle(); assert.equal(dock.expanded, false); assert.equal(dock.progress, 0);
dock.reduceMotion = true; dock.toggle(); assert.equal(durations.at(-1), 0); assert.equal(dock.progress, 1);
dock.motionChanged(); assert.equal(dock.progress, 1);
for (const height of [640, 800, 1100]) { dock.windowHeight = height; const top = dock.top(); assert(top >= dock.topInset + 108); assert(top + 300 <= height - dock.bottomInset); }
console.log('PASS: rapid dock reversal settles to latest intent; grip side stays fixed while open; reduced motion skips rotation timing; rail fits tested phone heights.');
