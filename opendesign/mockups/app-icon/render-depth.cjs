const fs = require('node:fs');
const path = require('node:path');
const { Resvg } = require('../../../build/icon-render/node_modules/@resvg/resvg-js');

const outputDirectory = path.join(__dirname, 'soft-depth');
fs.mkdirSync(outputDirectory, { recursive: true });
const original = fs.readFileSync(path.join(__dirname, 'icon.svg'), 'utf8');
const originalDefinitions = original.match(/<defs>([\s\S]*?)<\/defs>/)[1];
const bodyPath = 'M310 330H662Q702 330 702 370V596Q702 670 628 670H421L308 748V663Q270 647 270 606V370Q270 330 310 330Z';
const handlePath = 'M682 368H730C812 368 854 410 854 488V500C854 578 812 620 730 620H682V566H730Q798 566 798 500V488Q798 422 730 422H682Z';
const definitions = `<defs>${originalDefinitions}
  <linearGradient id="background" x1="0" y1="0" x2="0.85" y2="1">
    <stop stop-color="#64774F"/><stop offset="0.48" stop-color="#465C37"/><stop offset="1" stop-color="#34482B"/>
  </linearGradient>
  <radialGradient id="light" cx="0.2" cy="0.08" r="0.9">
    <stop stop-color="#DCE6BE" stop-opacity="0.15"/><stop offset="1" stop-color="#DCE6BE" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="ceramic" x1="0" y1="0" x2="0.65" y2="1">
    <stop stop-color="#FFFBF2"/><stop offset="0.5" stop-color="#F5EDDC"/><stop offset="1" stop-color="#E2D3B3"/>
  </linearGradient>
  <linearGradient id="handle" x1="0" y1="0" x2="1" y2="0.9">
    <stop stop-color="#E7DABD"/><stop offset="0.55" stop-color="#F5EDDC"/><stop offset="1" stop-color="#CDBD9B"/>
  </linearGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
    <stop stop-color="#FFF0BE"/><stop offset="0.24" stop-color="#EBD093"/><stop offset="0.68" stop-color="#D9B879"/><stop offset="1" stop-color="#BE9756"/>
  </linearGradient>
  <filter id="shadow" x="-30%" y="-25%" width="170%" height="175%" color-interpolation-filters="sRGB">
    <feGaussianBlur in="SourceAlpha" stdDeviation="15" result="blur"/>
    <feOffset in="blur" dx="9" dy="21" result="offset"/>
    <feFlood flood-color="#162211" flood-opacity="0.27"/>
    <feComposite in2="offset" operator="in" result="shadow"/>
    <feMerge><feMergeNode in="shadow"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="rimShadow" x="-20%" y="-80%" width="150%" height="320%" color-interpolation-filters="sRGB">
    <feGaussianBlur in="SourceAlpha" stdDeviation="4" result="blur"/>
    <feOffset in="blur" dx="0" dy="7" result="offset"/>
    <feFlood flood-color="#172410" flood-opacity="0.24"/>
    <feComposite in2="offset" operator="in" result="shadow"/>
    <feMerge><feMergeNode in="shadow"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>`;

function symbol(bodyFill, handleFill, edge = false) {
  const stroke = edge ? 'stroke="#FFFBEC" stroke-width="2" stroke-opacity="0.55"' : '';
  return `<path d="${handlePath}" fill="${handleFill}" transform="translate(-40 0)" ${stroke}/>
    <g mask="url(#story)"><path d="${bodyPath}" fill="${bodyFill}" transform="translate(-40 0)" ${stroke}/></g>`;
}

const backgroundLayers = '<rect width="1024" height="1024" fill="url(#background)"/><rect width="1024" height="1024" fill="url(#light)"/>';
const artwork = `<g filter="url(#shadow)">
  <g transform="translate(0 9)">${symbol('#B9AB8C', '#AFA182')}</g>
  ${symbol('url(#ceramic)', 'url(#handle)', true)}
</g>
<g filter="url(#rimShadow)">
  <rect x="230" y="268" width="432" height="44" rx="22" fill="#A47E43"/>
  <rect x="230" y="262" width="432" height="44" rx="22" fill="url(#gold)" stroke="#FFF1C6" stroke-opacity="0.65" stroke-width="2"/>
  <path d="M254 269H638" stroke="#FFF5D6" stroke-opacity="0.65" stroke-width="3" stroke-linecap="round"/>
</g>`;

function document(content) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><title>HarmonyTavern · 故事入杯 · 微立体版</title>${definitions}${content}</svg>`;
}

function exportSvg(name, svg, size = 1024) {
  fs.writeFileSync(path.join(outputDirectory, `${name}.svg`), svg);
  fs.writeFileSync(path.join(outputDirectory, `${name}.png`), new Resvg(svg, { fitTo: { mode: 'width', value: size }, font: { loadSystemFonts: true } }).render().asPng());
}

const master = document(backgroundLayers + artwork);
const rounded = document(`<defs><clipPath id="rounded"><rect width="1024" height="1024" rx="224"/></clipPath></defs><g clip-path="url(#rounded)">${backgroundLayers}<rect x="2" y="2" width="1020" height="1020" rx="222" fill="none" stroke="#F0F1D1" stroke-opacity="0.16" stroke-width="3"/>${artwork}</g>`);
const circular = document(`<defs><clipPath id="circle"><circle cx="512" cy="512" r="512"/></clipPath></defs><g clip-path="url(#circle)">${backgroundLayers}${artwork}</g>`);
exportSvg('icon', master);
exportSvg('icon-rounded', rounded);
exportSvg('foreground', document(artwork));
exportSvg('background', document(backgroundLayers));
for (const size of [512, 256, 128, 96, 64, 48, 32]) {
  fs.writeFileSync(path.join(outputDirectory, `icon-${size}.png`), new Resvg(master, { fitTo: { mode: 'width', value: size } }).render().asPng());
}

function embed(svg, x, y, size) {
  return `<image x="${x}" y="${y}" width="${size}" height="${size}" href="data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}"/>`;
}

const flat = original.replace('<rect width="1024" height="1024" fill="#465C37"/>', '<rect width="1024" height="1024" rx="224" fill="#465C37"/>');
const preview = `<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1060" viewBox="0 0 1440 1060">
  <rect width="1440" height="1060" fill="#F5F0E6"/>
  <g font-family="Microsoft YaHei, Noto Sans CJK SC, sans-serif" fill="#302B23">
    <text x="88" y="74" font-size="16" letter-spacing="3" fill="#465C37">HARMONYTAVERN / APP ICON</text>
    <text x="84" y="148" font-size="52" font-weight="700">故事入杯 · 微立体</text>
    <text x="1350" y="74" text-anchor="end" font-size="15" fill="#625847">02 / SOFT DEPTH</text>
    <path d="M88 188H1352" stroke="#D8CEBA"/>
    ${embed(flat, 154, 238, 420)}
    ${embed(rounded, 866, 238, 420)}
    <path d="M675 445H765M751 431L765 445L751 459" fill="none" stroke="#A39372" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    <text x="364" y="706" text-anchor="middle" font-size="23" font-weight="600">原版 · 平面</text>
    <text x="1076" y="706" text-anchor="middle" font-size="23" font-weight="600">新版 · 温润浮雕</text>
    <text x="720" y="772" text-anchor="middle" font-size="18" fill="#625847">柔和陶瓷杯身 / 麦金杯沿 / 轻薄侧边 / 左上方柔光</text>
    <path d="M88 820H1352" stroke="#D8CEBA"/>
    <text x="88" y="880" font-size="14" letter-spacing="2" fill="#625847">MASK &amp; SCALE</text>
    ${embed(rounded, 420, 858, 96)}${embed(circular, 626, 858, 96)}${embed(rounded, 856, 882, 48)}${embed(rounded, 1070, 890, 32)}
    <g font-size="14" text-anchor="middle" fill="#625847">
      <text x="468" y="994">圆角</text><text x="674" y="994">圆形</text><text x="880" y="994">48 px</text><text x="1086" y="994">32 px</text>
    </g>
  </g>
</svg>`;
exportSvg('preview', preview, 1440);
console.log(`Rendered soft-depth variant to ${outputDirectory}`);
