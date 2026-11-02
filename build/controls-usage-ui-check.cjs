const q=require('./ui-probe.cjs'),assert=require('assert');
for(const index of [1,0,2,1,2,0,1]) {
 q.tap(a=>a.id==='jelly-tab-item-'+index&&Number(a.bounds.match(/\d+/g)[1])<1000);
 const ns=q.nodes(),caption=ns.find(n=>n.a.id==='usage-heat-window'),refresh=ns.find(n=>n.a.id==='usage-refresh'),content=ns.find(n=>n.a.id==='usage-statistics-content');
 assert(caption);assert(caption.a.text.includes(index===1?'近30天':'过去12个月'));assert.equal(refresh.a.enabled,'true');assert.equal(refresh.a.opacity,'1.000000');assert.equal(content.a.opacity,'1.000000');
 const arrows=ns.filter(n=>n.a.text==='‹'||n.a.text==='›');assert.equal(arrows.length,2);assert.equal(arrows[0].a.enabled,'true');assert.equal(arrows[0].a.opacity,'1.000000');
 console.log(index,caption.a.text,'refresh node',refresh.a.hashcode,'arrows',arrows.map(n=>n.a.hashcode).join(','));
}
q.run('shell','snapshot_display','-f','/data/local/tmp/controls-usage-month-final.jpeg');q.run('file','recv','/data/local/tmp/controls-usage-month-final.jpeg',process.cwd()+'/build/controls-usage-month-final.jpeg');
const pid=q.run('shell','pidof','com.example.harmonytavern').trim();require('fs').writeFileSync('build/controls-assistant-runtime.log',q.run('shell','hilog','-x','-P',pid));

