const fs = require('fs');
const { execFileSync } = require('child_process');
const hdc = 'C:/Program Files/Huawei/DevEco Studios/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
function run(...args) {
  return execFileSync(hdc, ['-t', '127.0.0.1:5555', ...args], { encoding: 'utf8', timeout: 15000 });
}
function flatten(node) { return [node.attributes, ...(node.children || []).flatMap(flatten)].filter(Boolean); }
function nodes() {
  run('shell', 'uitest', 'dumpLayout', '-p', '/data/local/tmp/release-guide-layout.json');
  run('file', 'recv', '/data/local/tmp/release-guide-layout.json', 'build/release-guide-layout.json');
  return flatten(JSON.parse(fs.readFileSync('build/release-guide-layout.json', 'utf8')));
}
function tap(predicate) {
  const node = nodes().find(predicate);
  if (!node) { throw new Error('UI target missing'); }
  const bounds = node.bounds.match(/\d+/g).map(Number);
  run('shell', 'uitest', 'uiInput', 'click', String(Math.round((bounds[0] + bounds[2]) / 2)), String(Math.round((bounds[1] + bounds[3]) / 2)));
}
function shot(name) {
  run('shell', 'snapshot_display', '-f', '/data/local/tmp/release-guide.jpeg');
  run('file', 'recv', '/data/local/tmp/release-guide.jpeg', 'build/' + name + '.jpeg');
}
module.exports = { run, nodes, tap, shot };
