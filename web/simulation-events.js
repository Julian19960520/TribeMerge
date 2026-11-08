/* Stable source keys for new reports, with title-based compatibility for schema-1 reports. */
(function (root) {
  'use strict';
  const rewards = {
    level: ['等级奖励', '#f0c47b'], book: ['图鉴奖励', '#c6a2df'],
    daily: ['每日补给', '#ddb5eb'], seven_day_task: ['七日任务奖励', '#b99bea'],
    seven_day_stage: ['七日阶段奖励', '#e3a6d5'], pass: ['通行证奖励', '#9aabe9'],
    land: ['开地奖励', '#cbb67b'], chest: ['普通宝箱', '#d4a875'],
    choice_chest: ['自选宝箱', '#e7c57c'], cards: ['典藏卡包', '#db9dcd'],
    resource_energy: ['收取体力', '#e7aa71'], resource_shell: ['收取贝币', '#c6bf87'],
    resource_amber: ['收取琥珀', '#e7c258'], resource_sand: ['收取沙漏', '#bcb19e'],
    stash: ['暂存区领奖', '#c0a6cf'], duel_match: ['双人赛结算', '#7bccb1'],
    duel_milestone: ['双人赛胜场奖', '#a1d485'], banana: ['香蕉赛奖励', '#d4d878'],
    moon: ['月石奖励', '#87c9df'],
    ph_gather_fest: ['采集祭（占位）', '#9fd3a0'], ph_treasure_dig: ['部落寻宝（占位）', '#e0b98a'],
    ph_hunt_fest: ['狩猎大会（占位）', '#d99a8f'], ph_expedition: ['远征（占位）', '#8fb8d9'],
    ph_festival: ['节日庆典（占位）', '#d7a3d9'], other: ['其他领奖', '#bd9fc9']
  };
  const base = {
    start: ['开始', '#aeb6ba'], end: ['结束', '#aeb6ba'], level: ['等级提升', '#f3c66d'],
    milestone: ['里程碑', '#f3c66d'], build: ['升级部落', '#89c49a'],
    order_xp: ['经验订单', '#f3c66d'], order_no_xp: ['无经验订单', '#70b7d6'], unlock: ['主线解锁藤蔓', '#a6d66f'], unlock_moon: ['月石解锁藤蔓', '#87c9df'],
    craft: ['制作', '#80a0dc'], egen: ['点火种罐', '#e7aa71'], event: ['活动操作', '#5dd4c1'], wait: ['等待', '#657d87'], offline: ['下线', '#3f5058'], stuck: ['卡住下线', '#ff927e'],
    bottleneck: ['阻塞', '#ff927e'], error: ['异常', '#ff716e'], decision: ['决策', '#bdaf93'],
    storage: ['储物洞', '#c5ae81'], stash: ['取出暂存物品', '#c5ae81'], delete: ['丢弃', '#f29d75'],
    merge: ['合成', '#80a49e'], produce: ['生产', '#7693a1'], other: ['其他事件', '#aeb6ba']
  };
  const names = {}, colors = {};
  for (const [key, [name, color]] of Object.entries(base)) { names[key] = name; colors[key] = color; }
  for (const [key, [name, color]] of Object.entries(rewards)) { names['reward_' + key] = name; colors['reward_' + key] = color; }
  function isMoon(event) {
    return event.detail?.board === 'moon' || (event.title || '').startsWith('月石棋盘');
  }
  function category(event) {
    if (event.category === 'unlock') return isMoon(event) ? 'unlock_moon' : 'unlock';
    if (event.category === 'order') return Number(event.detail?.rw?.xp || 0) > 0 ? 'order_xp' : 'order_no_xp';
    if (event.category === 'merge' && event.reason === '解锁藤蔓' && !event.detail?.unlock_recorded) return isMoon(event) ? 'unlock_moon' : 'unlock';
    if (event.reward_source) return 'reward_' + (rewards[event.reward_source] ? event.reward_source : 'other');
    const title = event.title || '';
    if (event.category === 'event') {
      if (title === '双人竞速累计胜利奖励') return 'reward_duel_milestone';
      if (['双人竞速胜利', '双人竞速落败'].includes(title)) return 'reward_duel_match';
      if (title === '香蕉竞速结算') return 'reward_banana';
      if (title === '月石里程碑奖励') return 'reward_moon';
    }
    if (event.category !== 'reward') return base[event.category] ? event.category : 'other';
    if (/^领取 \d+ 级奖励$/.test(title)) return 'reward_level';
    if (title.startsWith('图鉴 · ')) return 'reward_book';
    const oldTitles = {
      '七日任务奖励': 'seven_day_task', '七日里程碑': 'seven_day_stage', '通行证免费奖励': 'pass',
      '领取每日免费补给': 'daily', '领取开地奖励': 'land', '打开宝箱': 'chest', '打开自选宝箱': 'choice_chest',
      '打开典藏卡包': 'cards', '领取暂存卡包': 'cards', '收取暂存资源': 'stash'
    };
    if (oldTitles[title]) return 'reward_' + oldTitles[title];
    if (title.startsWith('收取 ')) {
      const chain = (event.detail?.item || '').split('_')[0];
      const kind = { fire: 'energy', shell: 'shell', amber: 'amber', sand: 'sand' }[chain];
      if (kind) return 'reward_resource_' + kind;
    }
    return 'reward_other';
  }
  const minor = new Set(['decision', 'storage', 'stash', 'merge', 'produce']);
  function matches(event, all = false, selected = '') {
    const key = category(event);
    return (all || !minor.has(key)) && (!selected || selected === key);
  }
  /* Lanes are grouped; the page colours by group and can fold a group into one lane. */
  const groups = [
    { id: 'progress', label: '进度', color: '#3987e5' },
    { id: 'energy', label: '体力', color: '#d95926' },
    { id: 'reward', label: '奖励', color: '#9085e9' },
    { id: 'activity', label: '活动', color: '#199e70' },
    { id: 'misc', label: '其他', color: '#7d8c91' }
  ];
  const rewardGroup = { resource_energy: 'energy', duel_match: 'activity', duel_milestone: 'activity', banana: 'activity', moon: 'activity' };
  const tracks = [
    { label: '等级 / 里程碑', keys: ['level', 'milestone', 'start', 'end'], group: 'progress' },
    { label: '订单', keys: ['order_xp', 'order_no_xp'], group: 'progress' },
    { label: '升级部落', keys: ['build'], group: 'progress' },
    { label: '主线解锁藤蔓', keys: ['unlock'], group: 'progress' },
    { label: '制作', keys: ['craft'], group: 'progress' },
    { label: '卡体力', keys: ['stuck'], group: 'energy' },
    { label: '点火种罐', keys: ['egen'], group: 'energy' },
    ...Object.keys(rewards).map(key => ({ label: rewards[key][0], keys: ['reward_' + key], group: key.startsWith('ph_') ? 'activity' : rewardGroup[key] || 'reward' })),
    { label: '活动操作', keys: ['event'], group: 'activity' },
    { label: '月石解锁藤蔓', keys: ['unlock_moon'], group: 'activity' },
    { label: '物品整理', keys: ['storage', 'stash', 'delete'], group: 'misc' },
    { label: '合成 / 生产', keys: ['merge', 'produce'], group: 'misc' },
    { label: '决策 / 阻塞', keys: ['decision', 'bottleneck', 'error', 'other'], group: 'misc' },
    { label: '等待', keys: ['wait'], group: 'misc' }, { label: '下线', keys: ['offline'], group: 'misc' }
  ].sort((a, b) => groups.findIndex(g => g.id === a.group) - groups.findIndex(g => g.id === b.group));
  function lanes(events, all = false, selected = '') {
    const present = new Set(events.filter(event => matches(event, all, selected)).map(category));
    return tracks.filter(track => track.keys.some(key => present.has(key)));
  }
  function formatTime(seconds) {
    if (!Number.isFinite(Number(seconds))) return '未记录';
    const ticks = Math.max(0,Math.round(Number(seconds)*100));
    const hours=Math.floor(ticks/360000),minutes=Math.floor(ticks/6000)%60,secondsPart=(ticks%6000)/100;
    return (hours?`${hours}小时`:'')+(hours||minutes?`${minutes}分`:'')+`${secondsPart}秒`;
  }
  function eventTitle(event) {
    if ((event.category==='wait' || event.category==='offline') && Number.isFinite(event.detail?.seconds)) return '快进 '+formatTime(event.detail.seconds);
    return String(event.title || names[category(event)] || '事件');
  }
  function brief(event) {
    const key = category(event), detail = event.detail || {};
    let title = eventTitle(event);
    if (key === 'build') title = title.replace(/^升级部落\s*·\s*/, '');
    if (key === 'reward_book') title = title.replace(/^图鉴\s*·\s*/, '');
    if (key.startsWith('reward_resource_')) title = title.replace(/^收取\s*/, '');
    if (key === 'reward_level') {
      const level = detail.level ?? title.match(/(\d+)\s*级/)?.[1];
      return `${level == null ? '' : level+'级：'}${detail.received || '奖励内容未记录'}`;
    }
    if (key === 'reward_seven_day_task') return detail.task?.title || '领取';
    if (key === 'reward_seven_day_stage') return detail.stage?.title || '领取';
    if (key === 'reward_pass') return '领取免费档';
    if (key === 'reward_daily') return '领取免费补给';
    if (key === 'reward_land') return '领取';
    if (key === 'reward_chest' || key === 'reward_choice_chest') return '开启';
    if (key === 'reward_cards') return title.includes('暂存') ? '领取暂存卡包' : '开启';
    if (key === 'reward_duel_match') {
      const outcome = title.replace(/^双人竞速/, '');
      const match = detail.match;
      return match ? `${outcome}（${match.me} : ${match.opponent}）` : outcome;
    }
    if (key === 'reward_duel_milestone') return detail.wins == null ? '领取' : `${detail.wins}胜`;
    if (key === 'reward_banana') return detail.place ? `第${detail.place}名` : '结算';
    if (key === 'reward_moon') return detail.milestones?.length ? `第${detail.milestones.map(index=>index+1).join('、')}阶段` : '领取';
    if (event.category === 'order') {
      const xp = Number(event.detail?.rw?.xp || 0);
      title += xp > 0 ? `（经验 +${xp}）` : '（无经验）';
    }
    return title;
  }
  function appendText(points, time, content) {
    points[time] = Object.hasOwn(points,time) ? points[time]+'；'+content : content;
  }
  function unlockPoint(groups, event, time) {
    const d = event.detail || {};
    const board = d.board === 'main' ? '主棋盘' : d.board === 'moon' ? '月石棋盘' : '未记录棋盘';
    const group = groups[board] ||= {};
    group[time] = {行:d.row ?? '未记录',列:d.col ?? '未记录'};
  }
  function compactReport(report, metricDefinitions) {
    const output = {格式:'TribeMerge时间线',时间格式:'x小时x分x秒（省略开头为0的单位）',轮次:[]};
    const metrics = metricDefinitions.filter((metric,index,list) => typeof metric.key==='string' && metric.key!=='empty' && list.findIndex(other=>other.key===metric.key)===index);
    for (const run of report.runs) {
      const rows = report.events.filter(event=>event.run===run.run);
      const timelines = new Map(tracks.map(track=>[track.label,{}]));
      const trackFor = new Map(tracks.flatMap(track=>track.keys.map(key=>[key,track.label])));
      const series = new Map(metrics.map(metric=>[metric.key,{}]));
      for (const event of rows) {
        const time = Number(event.time);
        if (!Number.isFinite(time)) continue;
        const key = category(event), label = trackFor.get(key);
        const at = formatTime(time);
        if (key==='unlock' || key==='unlock_moon') unlockPoint(timelines.get(label),event,at);
        else if (label && key!=='merge' && key!=='produce') appendText(timelines.get(label),at,brief(event));
        for (const metric of metrics) {
          const value = event.state?.[metric.key];
          if (!Number.isFinite(value)) continue;
          // A timestamp represents the final value after all events at that instant.
          series.get(metric.key)[at] = value;
        }
      }
      for (const [key,points] of series) {
        let previous;
        series.set(key,Object.fromEntries(Object.entries(points).filter(([,value])=>{
          if (value===previous) return false;
          previous=value;
          return true;
        })));
      }
      output.轮次.push({轮次:run.run,
        时间线:Object.fromEntries([...timelines].filter(([,points])=>Object.keys(points).length)),
        资源与进度:Object.fromEntries(metrics.filter(metric=>Object.keys(series.get(metric.key)).length).map(metric=>[metric.label,series.get(metric.key)]))
      });
    }
    return output;
  }
  root.SimulationEvents = { names, colors, groups, tracks, category, matches, lanes, compactReport, formatTime, eventTitle, brief };
})(globalThis);
