const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const storage = new Map();
const persisted = new Map();
const context = {
  exports: {},
  AppStorage: { get: key => storage.get(key) },
  require: key => {
    assert.equal(key, './PersonalizationStore');
    return { PersonalizationStore: { set: (name, value) => { storage.set(name, value); persisted.set(name, value); } } };
  }
};
vm.createContext(context);
vm.runInContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/theme/OnboardingState.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, context);
const { OnboardingState, ONBOARDING_VERSION_KEY, ONBOARDING_VERSION } = context.exports;
assert.equal(OnboardingState.shouldShow(), true);
storage.set('appearanceBackground', 'rpg_sakura');
storage.set('lightSenseBlur', 19);
storage.set('activeProviderId', 'saved-provider');
OnboardingState.complete();
assert.equal(OnboardingState.shouldShow(), false);
assert.equal(persisted.get(ONBOARDING_VERSION_KEY), ONBOARDING_VERSION);
assert.equal(storage.get('appearanceBackground'), 'rpg_sakura');
assert.equal(storage.get('lightSenseBlur'), 19);
assert.equal(storage.get('activeProviderId'), 'saved-provider');
storage.clear();
for (const [key, value] of persisted) { storage.set(key, value); }
assert.equal(OnboardingState.shouldShow(), false);
storage.set(ONBOARDING_VERSION_KEY, ONBOARDING_VERSION + 1);
assert.equal(OnboardingState.shouldShow(), false);
storage.set(ONBOARDING_VERSION_KEY, 0);
assert.equal(OnboardingState.shouldShow(), true);
assert.match(fs.readFileSync('entry/src/main/ets/theme/PersonalizationStore.ets', 'utf8'), /key: 'onboardingCompletedVersion', value: 0/);
assert.equal(fs.readFileSync('entry/src/main/resources/rawfile/feedback/qq_group.jpg').subarray(0, 3).toString('hex'), 'ffd8ff');
console.log('PASS: first launch, persistent completion, restart, future-version retention, appearance/provider preservation, bundled QR original.');
