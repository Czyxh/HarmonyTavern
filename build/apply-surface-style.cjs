const fs = require('fs');
const path = require('path');
const result = [];
for (const dir of ['pages', 'components']) {
  for (const name of fs.readdirSync(`entry/src/main/ets/${dir}`).filter(n => n.endsWith('.ets'))) {
    const file = `entry/src/main/ets/${dir}/${name}`;
    const source = fs.readFileSync(file, 'utf8');
    let count = 0;
    let next = source.replace(/\.backgroundColor\(this\.(uiColors|colors)\.bgSurface\)(\s*)\.borderRadius\((Radius\.[a-z]+|\d+)\)(?!\s*\.attributeModifier\(new SurfaceStyle)/g,
      (match, colors, space, radius) => {
        count++;
        return `${match}${space}.attributeModifier(new SurfaceStyle(this.${colors}, ${radius}))`;
      });
    if (!count) continue;
    next = `import { SurfaceStyle } from '../theme/SurfaceStyles';\n` + next;
    fs.writeFileSync(file, next);
    result.push({file,count});
  }
}
fs.writeFileSync('build/surface-style-applied.json', JSON.stringify(result,null,2));
console.log(JSON.stringify(result));
