const fs = require('fs'), vm = require('vm'), assert = require('assert');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const hud = fs.readFileSync('entry/src/main/ets/components/WorldStatus.ets', 'utf8');
const methods = hud.slice(hud.indexOf('  private primaryMeter()'), hud.indexOf('  build()'));
const native = fs.readFileSync('entry/src/main/ets/backend/NativeWorld.ets', 'utf8');
const context = {}; vm.createContext(context);
vm.runInContext(ts.transpileModule(native.slice(native.indexOf('export function worldMeterPercent')).replace('export ', '') +
  '\nclass Hud {\n' + methods + '\n}\nglobalThis.Hud=Hud;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.None }
}).outputText, context);
const instance = new context.Hud(); instance.ready = true;
const meter = { kind: 'health', label: '生命', value: 45, max: 80 };
instance.state = { meters: [meter] }; assert.strictEqual(instance.percentLabel(), '56%');
assert.strictEqual(instance.meterColor(), '#D64545');
meter.value = 0; assert.strictEqual(instance.percentLabel(), '0%');
meter.value = 80; assert.strictEqual(instance.percentLabel(), '100%');
for (const maximum of [0, undefined, null, NaN, Infinity]) { meter.max = maximum; assert.strictEqual(instance.percentLabel(), '—'); }
meter.max = 80; meter.value = NaN; assert.strictEqual(instance.percentLabel(), '—');
instance.state = { meters: [{ kind: 'resource', value: 20, max: 40 }] }; assert.strictEqual(instance.percentLabel(), '—');
instance.ready = false; instance.state = { meters: [{ ...meter, value: 80 }] }; assert.strictEqual(instance.percentLabel(), '—');
const widget = hud.slice(hud.indexOf('  build()'), hud.indexOf('@Component\nexport struct WorldStatusDetails'));
assert(!widget.includes('Text(this.primaryMeter().label)')); assert(!widget.includes("Button('背包'"));
assert(!widget.includes("Button('状态'")); assert(!widget.includes('.border('));
assert(!widget.includes('backgroundColor(this.colors.headerButtonTint)'));
assert(widget.includes(".height(48).id('world-status-hud')"));
assert(widget.includes("app.media.icon_inventory")); assert(widget.includes("app.media.icon_status"));
assert(widget.includes(".backgroundColor('#2ED64545').direction(Direction.Ltr)"));
assert(widget.includes('.height(6).layoutWeight(1)'));
assert(widget.includes('.width(40).textAlign(TextAlign.End)'));
assert(widget.indexOf('Progress({') < widget.indexOf('Text(this.percentLabel())'));
assert(widget.includes("}.direction(Direction.Ltr).layoutWeight(1.3).id('world-health-left')"));
console.log('PASS: red-only health bar and rounded percentage; genuine zero distinguished from unknown/invalid data; resource meters never masquerade as health.');
console.log('PASS: compact 48vp HUD has no card background/border, no label/button text; backpack and status retain accessible icon buttons.');
const chat = fs.readFileSync('entry/src/main/ets/pages/ChatPage.ets', 'utf8');
const labelsMethod = chat.slice(chat.indexOf('  private chatMenuLabels()'), chat.indexOf('  @Builder\n  chatMenu()'));
vm.runInContext(ts.transpileModule('class Menu {\n' + labelsMethod + '\n}\nglobalThis.Menu=Menu;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.None }
}).outputText, context);
const menu = new context.Menu(); menu.statusText = 'private/session/path.jsonl · 1 条';
assert.strictEqual(menu.chatMenuLabels().length, 8);
assert(!menu.chatMenuLabels().some(label => label.includes('private/')));
menu.summaryVisible = true; menu.searchOpen = true;
assert(menu.chatMenuLabels().includes('收起摘要')); assert(menu.chatMenuLabels().includes('关闭搜索'));
const body = chat.slice(chat.indexOf('  chatMenu()'), chat.indexOf('  chatMenuCover()'));
assert(!body.includes('this.statusText')); assert(body.includes('fitMenuHeight'));
assert(!chat.includes('PageSurface(')); assert(!chat.includes('.mask('));
assert(chat.includes('.linearGradientBlur(glassEffect(GLASS_HEADER'));
const edgeMethod = chat.slice(chat.indexOf('  private chatHudInset()'), chat.indexOf('  @Builder\n  buildSurfaceContent()'));
vm.runInContext(ts.transpileModule('class Edge {\n' + edgeMethod + '\n}\nglobalThis.Edge=Edge;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.None }
}).outputText, context);
const edge = new context.Edge();
for (const height of [200, 600, 1200]) {
  for (const mode of ['free', 'world']) {
    edge.messageViewportHeight = height; edge.topInset = 24; edge.bottomInset = 112;
    edge.story = { mode }; edge.errorText = ''; edge.statusText = '';
    const stops = edge.chatEdgeStops();
    assert.strictEqual(stops.length, 4);
    assert.strictEqual(stops[0][0], 1); assert.strictEqual(stops[1][0], 0.65);
    assert.strictEqual(stops[2][0], 0); assert.strictEqual(stops[3][0], 0);
    assert(stops[2][1] <= 0.48); assert.strictEqual(stops[3][1], 1);
    for (let index = 1; index < stops.length; index++) {
      assert(stops[index][1] >= stops[index - 1][1]);
      assert(stops[index][0] <= stops[index - 1][0]);
    }
    if (height >= 600) {
      assert.strictEqual(Math.round(stops[1][1] * height), 56);
      assert.strictEqual(Math.round(stops[2][1] * height), 100);
      if (mode === 'world') assert.strictEqual(edge.chatHudInset(), 100);
      assert(edge.chatBottomReserve() >= edge.bottomInset);
    }
  }
}
assert(chat.includes('.contentStartOffset(this.topInset + 84)'));
assert(chat.includes('.contentEndOffset(this.chatBottomReserve())'));
assert(!chat.includes('.margin({ top: this.topInset + 76 })'));
const surface = fs.readFileSync('entry/src/main/ets/components/PageSurface.ets', 'utf8');
assert(surface.includes('@Prop edgeFades: boolean = true'));
assert(surface.includes('[0.65, (this.topInset + 32) / height]'));
assert(!surface.includes('bottomFull'));
assert(!chat.includes('bottomFull'));
assert(!surface.includes('.linearGradient({'));
assert(!surface.includes('fadeTop'));
assert(!chat.includes('.fadingEdge('));
console.log('PASS: eight-action menu excludes raw status/path, fits measured content; only top frost remains, monotonically fading to clear downward; the entire bottom stays clear and HUD placement is unchanged.');
