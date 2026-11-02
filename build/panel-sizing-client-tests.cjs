const fs = require('fs'), vm = require('vm'), assert = require('assert');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const context = { exports: {}, Observed: constructor => constructor };
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/theme/PanelSizing.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, experimentalDecorators: true }
}).outputText, context);
const sizing = new context.exports.PanelSizing();
assert.strictEqual(sizing.limit(600), 600);
sizing.update('header', 85.2); sizing.update('body', 190.1);
assert.strictEqual(sizing.limit(600), 277);
sizing.update('footer', 64); assert.strictEqual(sizing.limit(600), 341);
sizing.update('body', 1200); assert.strictEqual(sizing.limit(600), 600);
assert.strictEqual(sizing.limit(240), 240);
sizing.update('body', 100); sizing.update('footer', 0); assert.strictEqual(sizing.limit(600), 186);
sizing.update('body', NaN); sizing.update('body', -5); sizing.update('body', Infinity);
assert.strictEqual(sizing.limit(600), 186); assert.strictEqual(sizing.limit(0), 1);
const panel = fs.readFileSync('entry/src/main/ets/components/ChatPanel.ets', 'utf8');
const origin = fs.readFileSync('entry/src/main/ets/components/OriginPanel.ets', 'utf8');
assert(panel.includes("this.measure('header', current)")); assert(panel.includes("this.measure('body', current)"));
assert(panel.includes("this.measure('footer', current)")); assert(panel.includes(".width('100%').layoutWeight(1)"));
assert(origin.includes('this.state.contentHeight > 0 ? this.state.contentHeight : heightLimit')); assert(origin.includes('this.state.compact ? Math.max(1, Math.min(this.state.menuHeight'));
console.log('PASS: short content fits measured header/body/footer; long content and keyboard clamp to available height; dynamic shrink and invalid measurements are safe.');
console.log('PASS: intrinsic body measurement remains separate from scroll viewport; compact menus retain independent sizing.');
