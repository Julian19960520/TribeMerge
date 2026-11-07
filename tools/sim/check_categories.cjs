const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const zlib = require('node:zlib');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const scope = {};
vm.runInNewContext(fs.readFileSync(path.join(root, 'web/simulation-events.js'), 'utf8'), scope);
const { category, colors, matches, lanes, compactReport, formatTime, eventTitle } = scope.SimulationEvents;
assert.equal(formatTime(0),'0秒');
assert.equal(formatTime(8108),'2小时15分8秒');
assert.equal(formatTime(8),'8秒');
assert.equal(formatTime(128),'2分8秒');
assert.equal(formatTime(3608),'1小时0分8秒');
assert.equal(formatTime(90061.5),'25小时1分1.5秒');
assert.equal(formatTime(59.999),'1分0秒');
assert.equal(eventTitle({category:'wait',detail:{seconds:90}}),'快进 1分30秒');
function secondsOf(text){
  const match=/^(?:(\d+)小时)?(?:(\d+)分)?(\d+(?:\.\d+)?)秒$/.exec(text);
  assert(match,`unexpected time format: ${text}`);
  return Number(match[1]||0)*3600+Number(match[2]||0)*60+Number(match[3]);
}
const examples = [
  [{ category:'build',title:'升级部落' }, 'build'],
  [{ category:'order',title:'主线订单完成',detail:{story:true,rw:{xp:0}} }, 'order_no_xp'],
  [{ category:'order',title:'副线订单完成',detail:{story:false,rw:{xp:10}} }, 'order_xp'],
  [{ category:'order',title:'旧订单' }, 'order_no_xp'],
  [{ category:'unlock',title:'解锁藤蔓' }, 'unlock'],
  [{ category:'merge',reason:'解锁藤蔓',detail:{} }, 'unlock'],
  [{ category:'merge',reason:'解锁藤蔓',detail:{unlock_recorded:true} }, 'merge'],
  [{ category:'reward',title:'领取 2 级奖励' }, 'reward_level'],
  [{ category:'reward',title:'图鉴 · 草籽' }, 'reward_book'],
  [{ category:'reward',title:'领取每日免费补给' }, 'reward_daily'],
  [{ category:'reward',title:'七日任务奖励' }, 'reward_seven_day_task'],
  [{ category:'event',title:'月石里程碑奖励' }, 'reward_moon'],
  [{ category:'event',title:'参加双人竞速' }, 'event'],
  [{ category:'event',title:'双人竞速落败' }, 'reward_duel_match'],
  [{ category:'reward',title:'收取 篝火',detail:{item:'fire_4'} }, 'reward_resource_energy'],
  [{ category:'reward',title:'任意改名',reward_source:'book' }, 'reward_book'],
  [{ category:'reward',title:'未知新奖励',reward_source:'future' }, 'reward_other']
];
for (const [event,want] of examples) assert.equal(category(event), want);
assert.equal(colors.order_xp, '#f3c66d');
assert.equal(colors.order_no_xp, '#70b7d6');
assert(matches({category:'unlock'}));
assert(!matches({category:'merge',reason:'解锁藤蔓',detail:{unlock_recorded:true}}));
const report = JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(root,'web/simulation-report.json.gz'))));
for (const run of report.runs) {
  const rows=report.events.filter(event=>event.run===run.run);
  assert.equal(run.state.level,40);
  assert.equal(run.finish_reason,'target_level');
  const reached=rows.findIndex(event=>event.state.level>=40);
  assert(rows.slice(reached+1).every(event=>['level','end'].includes(event.category)));
  for(const event of rows.filter(event=>event.category==='reward')) assert(event.reward_source);
  const tracks=lanes(rows);
  assert.notEqual(tracks.findIndex(track=>track.keys.includes('build')),tracks.findIndex(track=>track.keys.includes('order_xp')));
  for(const event of rows.filter(event=>event.category==='order')) assert.equal(category(event),Number(event.detail.rw.xp||0)>0?'order_xp':'order_no_xp');
  if(report.resource_counting) assert(rows.some(event=>event.category==='unlock'));
  for (const event of rows.filter(event=>matches(event))) {
    assert.equal(tracks.filter(track=>track.keys.includes(category(event))).length,1);
    if(event.category==='reward') assert.notEqual(category(event),'reward_other');
  }
  const books=rows.filter(event=>matches(event,false,'reward_book'));
  assert(books.length>0 && books.every(event=>event.reward_source==='book'));
}
console.log(`PASS report categories, legacy imports, unique lanes, separate tribe/orders, and immediate Lv40 stop: ${report.events.length} events`);

const exampleReport={runs:[{run:1},{run:2}],events:[
  {run:1,time:0,category:'start',title:'开始',state:{gems:80},reason:'omit',detail:{private_snapshot:'omit'}},
  {run:1,time:.5,category:'order',title:'订单完成',detail:{rw:{xp:10}},state:{gems:85}},
  {run:1,time:.5,category:'reward',title:'奖励',state:{gems:90}},
  {run:1,time:1,category:'end',title:'结束',state:{gems:90}},
  {run:2,time:0,category:'start',title:'开始',state:{gems:80}}
]};
const example=JSON.parse(JSON.stringify(compactReport(exampleReport,[{key:'gems',label:'琥珀'},{key:'sand',label:'沙漏'}])));
assert.deepEqual(example.轮次[0].资源与进度.琥珀,{'0秒':80,'0.5秒':90});
assert.deepEqual(example.轮次[1].资源与进度.琥珀,{'0秒':80});
assert(!('沙漏' in example.轮次[0].资源与进度));
assert.equal(example.轮次[0].时间线.订单['0.5秒'],'订单完成（经验 +10）');
assert(!JSON.stringify(example).includes('omit'));
const filtered=compactReport({runs:[{run:1}],events:[
  {run:1,time:0,category:'start',title:'开始',state:{energy:10,empty:3}},
  {run:1,time:1,category:'produce',title:'生产',state:{energy:9,empty:2}},
  {run:1,time:2,category:'merge',title:'合成',state:{energy:9,empty:3}},
  {run:1,time:2,category:'unlock',title:'主棋盘 · 解锁藤蔓',detail:{board:'main',row:5,col:3,item_name:'草绳卷',result_name:'小草篓'},state:{energy:9,empty:3}},
  {run:1,time:3,category:'build',title:'升级部落 · 篝火广场'},
  {run:1,time:3,category:'build',title:'升级部落 · 织布坊'},
  {run:1,time:4,category:'reward',reward_source:'level',title:'领取 2 级奖励',detail:{level:2,received:'体力×50、藤编宝箱×1'}}
]},[{key:'energy',label:'体力'},{key:'empty',label:'棋盘空格'}]);
assert(!('合成 / 生产' in filtered.轮次[0].时间线));
assert(!('棋盘空格' in filtered.轮次[0].资源与进度));
assert.deepEqual(JSON.parse(JSON.stringify(filtered.轮次[0].时间线.解锁藤蔓)),{主棋盘:{'2秒':{行:5,列:3}}});
assert.equal(filtered.轮次[0].时间线.升级部落['3秒'],'篝火广场；织布坊');
assert.equal(filtered.轮次[0].时间线.等级奖励['4秒'],'2级：体力×50、藤编宝箱×1');
assert.deepEqual(JSON.parse(JSON.stringify(filtered.轮次[0].资源与进度.体力)),{'0秒':10,'1秒':9},'production still contributes resource changes despite being absent from timelines');

const html=fs.readFileSync(path.join(root,'web/simulation.html'),'utf8');
const options=html.match(/<select id="metric"[^>]*>([\s\S]*?)<\/select>/)[1];
const metrics=[...options.matchAll(/<option value="([^"]+)">([^<]+)<\/option>/g)].map(match=>({key:match[1],label:match[2]}));
for(const line of report.production_lines){
  metrics.push({key:line.metric,label:line.name+' · 折合一级份数'});
  if(line.max_metric)metrics.push({key:line.max_metric,label:line.name+' · 最高等级'});
}
const raw=JSON.stringify(report);
const exported=compactReport(report,metrics);
assert.equal(JSON.stringify(report),raw,'export must not mutate the report used by the page');
assert.equal(exported.轮次.length,report.runs.length);
for(const run of exported.轮次){
  const source=report.runs.find(item=>item.run===run.轮次);
  const rows=report.events.filter(event=>event.run===run.轮次);
  for(const track of lanes(rows,true)){
    if(track.keys.includes('merge') || track.keys.includes('unlock'))continue;
    const times=new Set(rows.filter(event=>track.keys.includes(category(event))).map(event=>formatTime(event.time)));
    assert.deepEqual(Object.keys(run.时间线[track.label]),[...times],'all retained event times are exported');
  }
  assert(!('合成 / 生产' in run.时间线));
  assert(!('棋盘空格' in run.资源与进度));
  function checkTimeLeaves(group){
    for(const [key,value] of Object.entries(group)){
      if(key==='解锁藤蔓')continue;
      if(typeof value==='object'){assert(!Array.isArray(value));checkTimeLeaves(value);}
      else {assert(Number.isFinite(secondsOf(key)));assert(['string','number'].includes(typeof value));}
    }
  }
  checkTimeLeaves(run.时间线);
  assert(Object.values(run.时间线.升级部落).every(value=>!value.includes('升级部落 · ')));
  const unlocks=rows.filter(event=>event.category==='unlock' && event.detail.row);
  assert.equal(Object.values(run.时间线.解锁藤蔓).reduce((count,points)=>count+Object.keys(points).length,0),unlocks.length,'all unlock coordinates are retained');
  for(const event of unlocks){
    const board=event.detail.board==='main'?'主棋盘':'月石棋盘';
    const point=run.时间线.解锁藤蔓[board][formatTime(event.time)];
    assert.deepEqual(JSON.parse(JSON.stringify(point)),{行:event.detail.row,列:event.detail.col});
  }
  for(const event of rows.filter(event=>category(event)==='reward_level' && event.detail.received)){
    assert(run.时间线.等级奖励[formatTime(event.time)].includes(event.detail.received));
  }
  for(const metric of metrics){
    const values=run.资源与进度[metric.label];
    if(!values)continue;
    const points=Object.entries(values);
    const first=rows.filter(event=>formatTime(event.time)===points[0][0] && Number.isFinite(event.state?.[metric.key])).at(-1);
    assert.equal(points[0][1],first.state[metric.key]);
    assert.equal(points.at(-1)[1],source.state[metric.key]);
    points.forEach((point,index)=>{
      assert(point.length===2&&Number.isFinite(secondsOf(point[0]))&&Number.isFinite(point[1]));
      if(index){assert(secondsOf(point[0])>=secondsOf(points[index-1][0]));assert.notEqual(point[1],points[index-1][1]);}
    });
  }
}
const serialized=JSON.stringify(exported);
for(const field of ['state','delta','detail','reason','config','source_hashes','seq'])assert(!serialized.includes(`"${field}":`));
assert(Buffer.byteLength(serialized)<Buffer.byteLength(raw)*.25);
console.log(`PASS concise export, excluded merge/production/empty records, preserved resource changes, resets and endpoint values: ${Buffer.byteLength(serialized)} bytes vs ${Buffer.byteLength(raw)} bytes`);
