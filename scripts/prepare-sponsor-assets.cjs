const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const sharp = require('../build/sponsor-tools/node_modules/sharp');
const jsQR = require('../build/sponsor-tools/node_modules/jsqr');
const { Resvg } = require('../build/icon-render/node_modules/@resvg/resvg-js');

const projectDirectory = path.resolve(__dirname, '..');
const mediaDirectory = path.join(projectDirectory, 'entry/src/main/resources/base/media');
const rawDirectory = path.join(projectDirectory, 'entry/src/main/resources/rawfile/sponsor');
const designDirectory = path.join(projectDirectory, 'opendesign/mockups/sponsor');
const sourceFiles = process.argv.slice(2);
assert.equal(sourceFiles.length, 2, 'Provide the Alipay image followed by the WeChat image.');
for (const directory of [rawDirectory, designDirectory]) {
  fs.mkdirSync(directory, { recursive: true });
}

async function decode(input, label = 'image') {
  const { data, info } = await sharp(input).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const result = jsQR(new Uint8ClampedArray(data), info.width, info.height);
  assert.ok(result, `QR code must remain readable: ${label}.`);
  return result;
}

function embed(input, x, y, width, height = width) {
  return `<image x="${x}" y="${y}" width="${width}" height="${height}" href="data:image/png;base64,${input.toString('base64')}"/>`;
}

async function prepare() {
  const providers = [
    { id: 'alipay', name: '支付宝', accent: '#1677FF', source: sourceFiles[0] },
    { id: 'wechat', name: '微信支付', accent: '#07A85B', source: sourceFiles[1] }
  ];
  const validation = [];
  const cup = fs.readFileSync(path.join(projectDirectory, 'opendesign/mockups/app-icon/perspective-cup/foreground.png'));
  await sharp(cup).extract({ left: 190, top: 230, width: 680, height: 570 }).png()
    .toFile(path.join(mediaDirectory, 'sponsor_cup.png'));
  for (const provider of providers) {
    const original = await decode(provider.source);
    const corners = [original.location.topLeftCorner, original.location.topRightCorner,
      original.location.bottomLeftCorner, original.location.bottomRightCorner];
    const minimumX = Math.min(...corners.map(corner => corner.x));
    const minimumY = Math.min(...corners.map(corner => corner.y));
    const maximumX = Math.max(...corners.map(corner => corner.x));
    const maximumY = Math.max(...corners.map(corner => corner.y));
    const span = Math.max(maximumX - minimumX, maximumY - minimumY);
    const moduleCount = 17 + original.version * 4;
    const quietZone = Math.ceil(span / moduleCount * 4.5);
    const size = Math.ceil(span) + quietZone * 2;
    const crop = { left: Math.floor((minimumX + maximumX - size) / 2),
      top: Math.floor((minimumY + maximumY - size) / 2), width: size, height: size };
    const qr = await sharp(provider.source).extract(crop).png().toBuffer();
    assert.equal((await decode(qr)).data, original.data, 'Cropped QR payload must match its original.');
    fs.writeFileSync(path.join(mediaDirectory, `sponsor_${provider.id}_qr.png`), qr);
    const cardSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1512" viewBox="0 0 1080 1512">
      <rect width="1080" height="1512" fill="#F5EDDC"/>
      <rect x="36" y="36" width="1008" height="1440" rx="56" fill="#FFFBF3" stroke="#DDD1BA" stroke-width="2"/>
      <g font-family="Microsoft YaHei, Noto Sans CJK SC, sans-serif" fill="#302B23" text-anchor="middle">
        ${embed(cup, 410, 48, 260)}
        <text x="540" y="296" font-size="26" letter-spacing="4" fill="#465C37">HARMONYTAVERN</text>
        <text x="540" y="388" font-size="54" font-weight="700">谢谢你，请开发者喝一杯</text>
        <text x="540" y="442" font-size="27" fill="#625847">你的支持，让下一段故事继续发生。</text>
        <rect x="330" y="490" width="420" height="64" rx="32" fill="${provider.accent}" fill-opacity="0.08"/>
        <circle cx="380" cy="522" r="8" fill="${provider.accent}"/>
        <text x="554" y="534" font-size="28" font-weight="600" fill="${provider.accent}">${provider.name} · 自愿赞助</text>
        <rect x="164" y="586" width="752" height="752" rx="32" fill="#FFFFFF" stroke="#E7DDCA" stroke-width="2"/>
        ${embed(qr, 202, 624, 676)}
        <text x="540" y="1392" font-size="28" font-weight="600" fill="#465C37">每一份心意，都很珍贵。</text>
        <text x="540" y="1436" font-size="23" fill="#625847">感谢你喜欢这间小酒馆，也谢谢你愿意支持独立开发。</text>
      </g>
    </svg>`;
    const card = new Resvg(cardSvg, { font: { loadSystemFonts: true } }).render().asPng();
    assert.equal((await decode(card, provider.id + ' card')).data, original.data, 'Designed card QR payload must match its original.');
    const compactCard = await sharp(card).resize({ width: 360, kernel: 'nearest' }).png().toBuffer();
    assert.equal((await decode(compactCard, provider.id + ' compact card')).data, original.data, 'Shared card must remain readable at phone display size.');
    fs.writeFileSync(path.join(designDirectory, `${provider.id}-card.svg`), cardSvg);
    fs.writeFileSync(path.join(rawDirectory, `${provider.id}_card.png`), card);
    fs.writeFileSync(path.join(designDirectory, `${provider.id}-card.png`), card);
    const phoneQr = await sharp(qr).resize({ width: 240, kernel: 'nearest' }).png().toBuffer();
    assert.equal((await decode(phoneQr)).data, original.data, 'QR must remain readable at in-app display size.');
    validation.push({ provider: provider.id, crop, quietZoneModules: 4.5,
      payloadSha256: crypto.createHash('sha256').update(original.data).digest('hex'),
      checks: ['original', 'crop', 'designed-card', '360px-card', '240px-qr'] });
    console.log(`Verified ${provider.name}: original, crop, designed card and phone-size images all encode the same recipient.`);
  }
  fs.writeFileSync(path.join(designDirectory, 'qr-validation.json'), JSON.stringify(validation, null, 2) + '\n');
}

prepare().catch(error => { console.error(error.message); process.exitCode = 1; });
