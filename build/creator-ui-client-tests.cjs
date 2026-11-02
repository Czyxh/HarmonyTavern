const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const store = new Map(), cache = new Map();
const backgroundColors = { sage: '#ECF2EC', sand: '#F4EEE6', mist: '#E8F0F4', moon: '#F0EDF6' };
const darkColors = { sage: '#18251D', sand: '#29231A', mist: '#17252E', moon: '#231D30' };
const storage = { get: key => store.get(key), setOrCreate: (key, value) => store.set(key, value) };
let resourcesReady = false;
const metrics = { resourceColor(value) {
  if (!resourcesReady) throw Error('UI resources are unavailable during cold-start palette initialization');
  let color = typeof value === 'string' && value.startsWith('#') ? value : '#F5EDDC';
  for (const [name, background] of Object.entries(backgroundColors)) {
    if (String(value).includes(name + 'Background')) color = store.get('appearanceIsDark') ? darkColors[name] : background;
  }
  return { red: parseInt(color.slice(-6, -4), 16), green: parseInt(color.slice(-4, -2), 16), blue: parseInt(color.slice(-2), 16),
    alpha: 255, color, blendAlpha() { return { color }; } };
} };
function load(file) {
  file = path.resolve(file);
  if (cache.has(file)) return cache.get(file);
  const exports = {};
  const context = { exports, AppStorage: storage, $r: value => value,
    BlurStyleActivePolicy: { ALWAYS_ACTIVE: 1 }, AdaptiveColor: { DEFAULT: 0 },
    require(specifier) {
      if (specifier === '@kit.ArkUI') return { ColorMetrics: metrics, ThemeControl: {} };
      if (specifier === '@kit.BasicServicesKit') return { deviceInfo: { sdkApiVersion: 26 } };
      if (specifier === './PersonalizationStore') return { PersonalizationStore: { getString: (_, fallback) => fallback, getBoolean: (_, fallback) => fallback } };
      if (specifier === './LightSense') return { LS_BLUR_REFERENCE: 60, LightSense: { blurRadius: () => 60 } };
      if (specifier === './Immersive') return { Immersive: { level: () => 1, presetOf: () => ({ blurRadius: 28 }) } };
      if (specifier.includes('SystemGlassNative')) throw Error('Native refraction must not load in frosted mode');
      return load(path.resolve(path.dirname(file), specifier + '.ets'));
    }
  };
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, context);
  cache.set(file, exports); return exports;
}
(async () => {
  const appearance = load('entry/src/main/ets/theme/Appearance.ets').Appearance;
  for (const dark of [false, true]) {
    store.set('appearanceIsDark', dark);
    for (const name of Object.keys(backgroundColors)) {
      const colors = appearance.colors(name);
      assert.notStrictEqual(colors.accent, 'app.color.accent');
      assert.notStrictEqual(colors.glassTint, 'app.color.glassTint');
      assert(colors.glassTint.startsWith('#')); assert(colors.accent.startsWith('#'));
      assert.strictEqual(colors.bgBase, 'app.color.' + name + 'Background');
      const entries = JSON.parse(fs.readFileSync('entry/src/main/resources/' + (dark ? 'dark' : 'base') + '/element/appearance.json', 'utf8')).color;
      const actualBase = entries.find(entry => entry.name === name + 'Background').value;
      assert(load('entry/src/main/ets/theme/CustomPalette.ets').CustomPalette.contrast(colors.textPrimary, actualBase) >= 7);
    }
  }
  console.log('PASS: sage/sand/mist/moon secondary surfaces and controls derive theme colors in both display modes, not default pink.');
  resourcesReady = true;
  console.log('PASS: cold-start theme tokens remain readable without UI resource resolution; text contrast against actual light/dark resource backgrounds is at least 7:1.');
  const glass = load('entry/src/main/ets/theme/Glass.ets');
  const colors = appearance.colors('sage');
  for (const effect of [glass.frostedEffect(60, colors), glass.glassEffect(glass.GLASS_ORB, 60, 1, colors)]) {
    assert.strictEqual(effect.saturation, 1); assert.strictEqual(effect.brightness, 1); assert.strictEqual(effect.policy, 1);
    assert.strictEqual(effect.color, colors.glassTint);
  }
  assert.strictEqual(glass.frostedEffect(0, colors).radius, 0);
  assert.strictEqual(glass.frostedEffect(0, colors).color, colors.bgSurface);
  const system = load('entry/src/main/ets/theme/SystemGlass.ets').SystemGlass;
  store.set('systemMaterialAvailable', true);
  assert.strictEqual(await system.initialize(), false);
  assert.strictEqual(store.get('systemMaterialAvailable'), false);
  assert.strictEqual(system.supported(), false);
  console.log('PASS: plain frost uses neutral saturation/brightness, honors disabled blur, stays active and never loads native refractive TabBar/lens materials.');
  const tools = fs.readFileSync('entry/src/main/ets/pages/ToolsPage.ets', 'utf8');
  const methods = tools.slice(tools.indexOf('  confirmRestore('), tools.indexOf('  async runSearch()'));
  let restored = 0, opened = 0, closed = 0;
  const context = { Backend: { restoreSettingsSnapshot: async () => { restored++; } } }; vm.createContext(context);
  vm.runInContext(ts.transpileModule('class Harness {\n' + methods + '\n}\nglobalThis.Harness=Harness;', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.None }
  }).outputText, context);
  const harness = new context.Harness();
  harness.restoreOrigin = { open(context, source, ratio) { assert(ratio > 0 && ratio <= 1); opened++; }, close() { closed++; } };
  harness.getUIContext = () => ({ showAlertDialog() { throw Error('System dialog is not allowed'); } });
  harness.reload = async () => {};
  harness.confirmRestore({ name: 'snapshot.json' });
  assert.strictEqual(opened, 1); assert.strictEqual(restored, 0); assert.strictEqual(harness.pendingRestore.name, 'snapshot.json');
  const pending = harness.restore(harness.pendingRestore); await harness.restore(harness.pendingRestore); await pending;
  assert.strictEqual(restored, 1); assert.strictEqual(closed, 1); assert.strictEqual(harness.busy, false);
  harness.busy = true; harness.confirmRestore({ name: 'other.json' }); assert.strictEqual(opened, 1);
  console.log('PASS: themed confirmation does not restore before explicit confirmation, prevents duplicate actions and closes only after successful restore.');
  const hud = fs.readFileSync('entry/src/main/ets/components/WorldStatus.ets', 'utf8');
  const primaryMethod = hud.slice(hud.indexOf('  private primaryMeter()'), hud.indexOf('  private meterColor()'));
  const hudContext = {}; vm.createContext(hudContext);
  vm.runInContext(ts.transpileModule('class Hud {\n' + primaryMethod + '\n}\nglobalThis.Hud=Hud;', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.None }
  }).outputText, hudContext);
  const instance = new hudContext.Hud(); instance.state = { meters: [{ kind: 'resource', label: '体力' }, { kind: 'health', label: '生命' }] };
  assert.strictEqual(instance.primaryMeter().label, '生命'); instance.ready = true; instance.state.meters = [];
  assert.strictEqual(instance.primaryMeter().label, '未定义指标');
  assert(hud.includes(".id('world-health-left')")); assert(hud.includes(".id('world-status-right')"));
  assert(hud.includes(".id('chat-world-inventory')")); assert(hud.includes('ScrollDirection.Horizontal'));
  console.log('PASS: health is selected independently of meter ordering; unknown metrics stay honest; dedicated inventory and horizontal status targets present.');
})().catch(error => { console.error(error); process.exitCode = 1; });
