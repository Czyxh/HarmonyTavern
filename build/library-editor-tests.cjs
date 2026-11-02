const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const ts = require('C:/Program Files/Huawei/DevEco Studios/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript');
const root = 'entry/src/main/ets/';
function evaluate(source, context) {
  vm.createContext(context);
  vm.runInContext(ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText, context);
  return context;
}
const { exports: { CharacterEditing } } = evaluate(fs.readFileSync(root + 'backend/CharacterEditing.ets', 'utf8'), { exports: {}, require: () => ({}) });
const card = { name: 'Seraphina', avatar: 'default_Seraphina.png', description: 'description', personality: 'kind', scenario: 'harbor', first_mes: 'hello', mes_example: 'example', creator: 'author', creator_notes: 'notes', character_version: '2', tags: ['a', 'b'], system_prompt: 'prompt', post_history_instructions: 'post', alternate_greetings: ['one', 'two'], extensions: { private: true }, character_book: { entries: [{ content: 'lore' }] } };
const form = CharacterEditing.form(card);
assert.equal(form.originalName, 'default_Seraphina');
form.description = 'edited'; form.tags = 'a，b,a\nc'; form.alternateGreetings.push('three');
const updated = { ...card, ...CharacterEditing.update(form) };
assert.equal(updated.personality, 'kind'); assert.equal(updated.scenario, 'harbor'); assert.equal(updated.mes_example, 'example');
assert.equal(updated.system_prompt, 'prompt'); assert.equal(updated.post_history_instructions, 'post');
assert.deepEqual(Array.from(updated.tags), ['a', 'b', 'c']); assert.equal(card.alternate_greetings.length, 2);
assert.equal(updated.character_book, card.character_book); assert.equal(updated.extensions, card.extensions);
function methods(file, start, end) { const source = fs.readFileSync(root + 'pages/' + file, 'utf8'); return source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start))); }
let renameCalls = 0, failUpdate = true, savedKey;
const characters = evaluate('class Harness {\n' + methods('CharactersPage.ets', '  async save()', '  async duplicate(') + '\n} exports.Harness = Harness;', {
  exports: {}, CharacterEditing, hilog: { error() {} }, DOMAIN: 0, TAG: '',
  Backend: { renameCharacter: async dto => { renameCalls++; assert.equal(dto.old_name, 'default_Seraphina'); return { ...card, name: 'NewName', avatar: 'NewName.png' }; }, updateCharacter: async key => { savedKey = key; if (failUpdate) throw Error('retry'); } }
}).exports.Harness;
const worldSource = methods('WorldInfoPage.ets', '  private entryKey(', '  confirmRemoveEntry(') + methods('WorldInfoPage.ets', '  async saveEntry(', '  /** 切换');
let worldSaved;
const book = { custom: { keep: true }, entries: { customKey: { uid: 7, key: ['old'], content: 'old', useProbability: false, probability: 50, custom: 'preserved', enabled: true } } };
const worlds = evaluate('class Harness {\n' + worldSource + '\n} exports.Harness = Harness;', { exports: {}, Backend: { getWorldInfo: async () => structuredClone(book), saveWorldInfo: async (name, data) => { worldSaved = data; } } }).exports.Harness;
(async () => {
  const editor = new characters(); editor.form = CharacterEditing.form(card); editor.form.name = 'NewName'; editor.reload = async () => {};
  await editor.save(); assert.equal(savedKey, 'NewName'); assert.equal(editor.form.originalName, 'NewName');
  failUpdate = false; await editor.save(); assert.equal(renameCalls, 1); assert.equal(savedKey, 'NewName');
  const world = new worlds(); Object.assign(world, { selected: 'Book', editingOrder: '120', editingProbability: '50', editingUseProbability: false, editingSelective: true, editingKeys: '龙，dragon', editingContent: 'new', editingComment: 'title', editingSecondary: 'harbor,port', cancelEdit() {}, async openBook() {} });
  await world.saveEntry({ uid: 7 });
  assert.equal(worldSaved.entries.customKey.useProbability, false); assert.equal(worldSaved.entries.customKey.custom, 'preserved');
  assert.equal(worldSaved.entries.customKey.content, 'new'); assert.equal(worldSaved.custom.keep, true);
  assert.deepEqual(Array.from(worldSaved.entries.customKey.key), ['龙', 'dragon']);
  worldSaved = undefined; world.editingProbability = '101'; await world.saveEntry({ uid: 7 }); assert.equal(worldSaved, undefined);
  console.log('PASS: full role fields, independent greetings, unknown card/book fields, storage keys, rename retry and probability semantics.');
})().catch(error => { console.error(error); process.exitCode = 1; });
