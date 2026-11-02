const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const storage = new Map();
const modules = {
  './PersonalizationStore': { PersonalizationStore: { set: (key, value) => storage.set(key, value) } },
  '@kit.ArkUI': { ThemeControl: { setDefaultTheme: () => {} } }
};
function load(name) {
  const context = { exports: {}, require: key => modules[key] || {}, $r: value => value,
    AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) } };
  vm.createContext(context);
  vm.runInContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/theme/' + name + '.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, context);
  modules['./' + name] = context.exports;
  return context.exports;
}
load('Tokens');
const { CustomPalette } = load('CustomPalette');
const { RpgThemes, RPG_THEMES } = load('RpgThemes');
const { Appearance } = load('Appearance');
const spec = JSON.parse(fs.readFileSync('opendesign/design-systems/harmonytavern/tokens/rpg-themes.json', 'utf8'));
storage.set('lightSenseBlur', 17);
storage.set('immersiveLevel', 2);
assert.equal(RPG_THEMES.length, 4);
for (const dark of [false, true]) {
  storage.set('appearanceIsDark', dark);
  assert.equal(Appearance.palettes().length, 11);
  for (const theme of RPG_THEMES) {
    const definition = spec.themes.find(item => item.id === theme.id);
    assert(definition);
    const mode = dark ? 'dark' : 'light';
    assert.deepEqual(JSON.parse(JSON.stringify(theme[mode])), definition[mode]);
    const colors = Appearance.colors(theme.id);
    assert.equal(colors.bgBase, definition[mode].background);
    assert.equal(colors.bgSurface, definition[mode].surface);
    assert.equal(colors.bgSurfaceHigh, definition[mode].surfaceHigh);
    const baselineMaterial = CustomPalette.colors(definition[mode].background, definition[mode].accent);
    for (const material of ['glassTint', 'glassEdge', 'dockTint', 'lensTint', 'headerButtonTint']) {
      assert.equal(colors[material].slice(1, 3), baselineMaterial[material].slice(1, 3),
        theme.id + mode + ' preserves ' + material + ' opacity');
    }
    assert.equal(Appearance.palette(theme.id).id, theme.id);
    assert.equal(Appearance.palette(theme.id).background, colors.bgBase);
    assert.equal(Appearance.theme(theme.id).colors.iconPrimary, colors.textPrimary);
    Appearance.selectBackground(theme.id);
    assert.equal(storage.get('lightSenseBlur'), 17);
    assert.equal(storage.get('immersiveLevel'), 2);
    assert.equal(storage.get('appearanceBackground'), theme.id);
    assert.equal(storage.get('uiColors').bgBase, colors.bgBase);
    assert.equal(RpgThemes.radius(20), theme.radius);
    assert.equal(RpgThemes.borderWidth(.65), theme.borderWidth);
    for (const surface of [colors.bgBase, colors.bgSurface, colors.bgSurfaceHigh, colors.accentContainer]) {
      assert(CustomPalette.contrast(colors.textPrimary, surface) >= 7, theme.id + mode + ' primary');
      for (const semantic of ['textSecondary', 'textTertiary', 'accent', 'danger', 'success', 'warning']) {
        assert(CustomPalette.contrast(colors[semantic], surface) >= 4.5, theme.id + mode + semantic);
      }
    }
    assert(CustomPalette.contrast(colors.textInverse, colors.accent) >= 4.5);
    for (const method of ['art', 'texture', 'frame']) {
      const resource = RpgThemes[method](theme.id).split('.').pop();
      const extension = method === 'art' ? '.jpg' : '.png';
      const appPath = 'entry/src/main/resources/base/media/' + resource + extension;
      const previewPath = 'opendesign/mockups/rpg-themes/assets/' + resource + extension;
      assert(fs.existsSync(appPath), appPath);
      assert.deepEqual(fs.readFileSync(appPath), fs.readFileSync(previewPath));
    }
  }
}
Appearance.selectBackground('paper');
assert.equal(RpgThemes.active(), undefined);
assert.equal(RpgThemes.radius(20), 20);
assert.equal(RpgThemes.borderWidth(.65), .65);
assert.equal(Appearance.colors('paper').bgBase, 'app.color.paperBackground');
assert.equal(Appearance.palette('invalid').id, 'paper');
assert.equal(Appearance.colors('rose').bgBase, '#281E25');
storage.set('appearanceIsDark', false);
assert.equal(Appearance.colors('rose').bgBase, '#F4E5EB');
for (const id of ['sage', 'sand', 'mist', 'moon', 'custom']) {
  assert.equal(Appearance.palette(id).id, id);
}
console.log('PASS: four RPG themes × day/night, token parity, text contrast, selection persistence, assets, icons and existing-theme fallback.');
