const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { Resvg } = require('../build/icon-render/node_modules/@resvg/resvg-js');

const projectDirectory = path.resolve(__dirname, '..');
const designDirectory = path.join(projectDirectory, 'opendesign/mockups/app-icon/perspective-cup');
const backupDirectory = path.join(projectDirectory, 'backups/app-icon-before-white-cup');
const foregroundSvg = fs.readFileSync(path.join(designDirectory, 'foreground-line.svg'), 'utf8');
const whiteBackground = '<rect width="1024" height="1024" fill="#FFFFFF"/>';
const backgroundSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${whiteBackground}</svg>`;
const iconSvg = foregroundSvg.replace(/(<svg\b[^>]*>)/, `$1${whiteBackground}`);

function render(svg, size) {
  return new Resvg(svg, { fitTo: { mode: 'width', value: size } }).render();
}

function replaceResource(relativePath, data) {
  const targetPath = path.join(projectDirectory, relativePath);
  const backupPath = path.join(backupDirectory, relativePath);
  if (fs.existsSync(targetPath) && !fs.existsSync(backupPath)) {
    fs.mkdirSync(path.dirname(backupPath), { recursive: true });
    fs.copyFileSync(targetPath, backupPath);
  }
  fs.writeFileSync(targetPath, data);
}

const foreground = render(foregroundSvg, 1024);
const background = render(backgroundSvg, 1024);
const icon = render(iconSvg, 1024);
assert.deepEqual(Array.from(foreground.pixels.subarray(0, 4)), [0, 0, 0, 0]);
const backgroundPixels = background.pixels;
assert.ok(backgroundPixels.every(channel => channel === 255));
assert.deepEqual(Array.from(icon.pixels.subarray(0, 4)), [255, 255, 255, 255]);

for (const resourceDirectory of ['AppScope/resources/base/media', 'entry/src/main/resources/base/media']) {
  replaceResource(`${resourceDirectory}/foreground.png`, foreground.asPng());
  replaceResource(`${resourceDirectory}/background.png`, background.asPng());
}
replaceResource('entry/src/main/resources/base/media/startIcon.png', render(foregroundSvg, 144).asPng());

fs.writeFileSync(path.join(designDirectory, 'icon-white.svg'), iconSvg);
fs.writeFileSync(path.join(designDirectory, 'icon-white.png'), icon.asPng());
fs.writeFileSync(path.join(designDirectory, 'icon-line-transparent.png'), foreground.asPng());
fs.writeFileSync(path.join(designDirectory, 'background-white.svg'), backgroundSvg);
fs.writeFileSync(path.join(designDirectory, 'background-white.png'), background.asPng());
console.log('Updated AppScope and entry layered icons: larger black-outline cup + pure white background.');
console.log('Updated transparent 144px start icon. Original resources backed up under backups/app-icon-before-white-cup.');
