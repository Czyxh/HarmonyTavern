const fs = require('node:fs');
const path = require('node:path');
const { Resvg } = require('../../../build/icon-render/node_modules/@resvg/resvg-js');

const outputDirectory = __dirname;
const master = fs.readFileSync(path.join(outputDirectory, 'icon.svg'), 'utf8');
const background = '<rect width="1024" height="1024" fill="#465C37"/>';
const foreground = master.replace(background, '');
const rounded = master.replace(background, '<rect width="1024" height="1024" rx="224" fill="#465C37"/>');
const monochrome = foreground.replaceAll('#F5EDDC', '#465C37').replaceAll('#D9B879', '#465C37');

function render(svg, filename, size) {
  const renderer = new Resvg(svg, { fitTo: { mode: 'width', value: size }, font: { loadSystemFonts: true } });
  fs.writeFileSync(path.join(outputDirectory, filename), renderer.render().asPng());
}

function embed(svg, x, y, size) {
  const encoded = Buffer.from(svg).toString('base64');
  return `<image x="${x}" y="${y}" width="${size}" height="${size}" href="data:image/svg+xml;base64,${encoded}"/>`;
}

fs.writeFileSync(path.join(outputDirectory, 'foreground.svg'), foreground);
fs.writeFileSync(path.join(outputDirectory, 'monochrome.svg'), monochrome);
fs.writeFileSync(path.join(outputDirectory, 'background.svg'), '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"><rect width="1024" height="1024" fill="#465C37"/></svg>');
render(master, 'icon-1024.png', 1024);
render(rounded, 'icon-rounded.png', 1024);
render(foreground, 'foreground.png', 1024);
render(fs.readFileSync(path.join(outputDirectory, 'background.svg'), 'utf8'), 'background.png', 1024);
for (const size of [512, 256, 128, 96, 64, 48, 32]) {
  render(master, `icon-${size}.png`, size);
}

const circular = master.replace(background, '<circle cx="512" cy="512" r="512" fill="#465C37"/>');
const dark = rounded.replaceAll('#465C37', '#242B20').replaceAll('#F5EDDC', '#EAE0CC');
const preview = `<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1040" viewBox="0 0 1440 1040">
  <rect width="1440" height="1040" fill="#F5F0E6"/>
  <g font-family="Microsoft YaHei, Noto Sans CJK SC, sans-serif" fill="#302B23">
    <text x="88" y="82" font-size="17" letter-spacing="3" fill="#465C37">HARMONYTAVERN / APP ICON</text>
    <text x="84" y="158" font-size="56" font-weight="700">故事入杯</text>
    <text x="1348" y="82" text-anchor="end" font-size="15" fill="#625847">01 / VECTOR DESIGN</text>
    <path d="M88 196H1352" stroke="#D8CEBA"/>
    ${embed(rounded, 88, 244, 440)}
    <text x="308" y="736" text-anchor="middle" font-size="23" font-weight="600">HarmonyTavern</text>
    <text x="308" y="770" text-anchor="middle" font-size="16" fill="#625847">让故事自由生长</text>
    <text x="648" y="284" font-size="30" font-weight="700">一杯故事，一场对话。</text>
    <text x="648" y="330" font-size="18" fill="#625847">为角色扮演、对话与世界共创而设计。</text>
    <g font-size="21" font-weight="600">
      <text x="648" y="406">酒杯</text><text x="648" y="490">气泡</text><text x="648" y="574">书页</text>
    </g>
    <g font-size="17" fill="#625847">
      <text x="744" y="406">杯沿与杯柄，保留「酒馆」的辨识。</text>
      <text x="744" y="490">杯身延伸为对话尾角，回应角色聊天。</text>
      <text x="744" y="574">负形打开一本书，承接故事与世界设定。</text>
    </g>
    <g transform="translate(648 636)">
      <circle cx="12" cy="12" r="12" fill="#465C37"/><text x="34" y="18" font-size="15">苔绿</text>
      <circle cx="145" cy="12" r="12" fill="#F5EDDC" stroke="#CFC3AC"/><text x="167" y="18" font-size="15">纸白</text>
      <circle cx="278" cy="12" r="12" fill="#D9B879"/><text x="300" y="18" font-size="15">麦金</text>
    </g>
    <path d="M88 822H1352" stroke="#D8CEBA"/>
    <text x="88" y="872" font-size="14" letter-spacing="2" fill="#625847">MASK &amp; SCALE</text>
    ${embed(rounded, 352, 864, 96)}
    ${embed(circular, 500, 864, 96)}
    ${embed(dark, 648, 864, 96)}
    ${embed(monochrome, 796, 864, 96)}
    ${embed(rounded, 969, 888, 48)}
    ${embed(rounded, 1117, 896, 32)}
    <g font-size="13" fill="#625847" text-anchor="middle">
      <text x="400" y="990">圆角</text><text x="548" y="990">圆形</text><text x="696" y="990">深色预览</text>
      <text x="844" y="990">单色</text><text x="993" y="990">48 px</text><text x="1133" y="990">32 px</text>
    </g>
  </g>
</svg>`;
fs.writeFileSync(path.join(outputDirectory, 'preview.svg'), preview);
render(preview, 'preview.png', 1440);
console.log(`Rendered icon assets and presentation to ${outputDirectory}`);
