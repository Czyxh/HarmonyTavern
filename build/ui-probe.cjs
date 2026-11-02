const cp = require('child_process'), fs = require('fs');
const hdc = 'C:/Program Files/Huawei/DevEco Studios/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const run = (...args) => cp.execFileSync(hdc, ['-t', process.env.QA_TARGET || '127.0.0.1:5555', ...args], {encoding:'utf8',windowsHide:true});
function nodes() {
  run('shell','uitest','dumpLayout','-p','/data/local/tmp/global-ui.json');
  run('file','recv','/data/local/tmp/global-ui.json',process.cwd()+'\\build\\global-ui.json');
  const out=[];
  function walk(n,p=[]) { const a=n.attributes||{};out.push({a,p});for(const c of n.children||[])walk(c,[...p,a]); }
  walk(JSON.parse(fs.readFileSync('build/global-ui.json','utf8')));return out;
}
function tap(predicate, ancestor=false) {
  const n=nodes().find(n=>predicate(n.a));if(!n)throw Error('Target absent; no tap');
  const a=ancestor?[...n.p].reverse().find(a=>a.clickable==='true'):n.a;
  const b=a.bounds.match(/\d+/g).map(Number);
  run('shell','uinput','-S','-c',String((b[0]+b[2])>>1),String((b[1]+b[3])>>1));
}
module.exports={run,nodes,tap};
