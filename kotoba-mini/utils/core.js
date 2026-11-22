'use strict';
// Pure functions shared by the WeChat mini program. No DOM, server or WeChat globals.
const SOURCE = require('../data/words.js');
const DAY = 86400000, MINUTE = 60000;
const INTERVAL_DAYS = [1, 3, 7, 14, 30, 60, 90];
const sourceLabels = {
  '名':'名词','副':'副词','イ形':'い形容词','ナ形':'な形容词',
  '他五':'他动词·五段','自五':'自动词·五段','自他五':'自／他动词·五段',
  '他上一':'他动词·一段','他下一':'他动词·一段','自上一':'自动词·一段',
  '自下一':'自动词·一段','自サ':'自动词·サ变','他サ':'他动词·サ变',
  '自他サ':'自／他动词·サ变','接頭':'接头词','接尾':'接尾词',
  '助数':'量词','连体':'连体词','连语':'固定表达'
};
function clean(v){ return String(v == null ? '' : v).trim().slice(0,180); }
function volumeOf(id){
  const s=String(id), m=s.match(/^([23])-(\d+)$/);
  if(m)return Number(m[1]);
  if(/^\d+$/.test(s))return Number(s)<10?3:2;
  return 0;
}
const lessons=SOURCE.lessons.map(x=>Object.assign({},x,{volume:volumeOf(x.id)}))
  .sort((a,b)=>b.volume-a.volume || Number(a.id)-Number(b.id));
function lessonName(id){
  const s=String(id),n=s.replace(/^[23]-/,'');
  return (volumeOf(s)===3?'第三册':'第二册')+' · 第'+n+'课';
}
function posLabel(tag){
  if(!tag)return '单词';
  const s=String(tag);
  return s.split('・').map(x=>sourceLabels[x]||x).join(' / ');
}
function normalizeAnswer(value){
  const s=String(value||'');
  const full=typeof s.normalize==='function'?s.normalize('NFKC'):s;
  return full.trim().toLowerCase().replace(/[\s　。、，,.!?！？・（）()「」『』]/g,'');
}
function answerCorrect(word, answer, mode){
  const v=normalizeAnswer(answer); if(!v)return false;
  if(mode==='cn-jp')return v===normalizeAnswer(word.jp)||v===normalizeAnswer(word.kana);
  return String(word.cn||'').split(/[；;，,、/]/)
    .map(x=>normalizeAnswer(x.replace(/（.*?）/g,''))).filter(Boolean).includes(v);
}
function buildLibrary(custom){
  const seen=new Map();
  const extras=Array.isArray(custom)?custom.slice(0,5000).map(w=>Object.assign({},w,{lesson:'extra',source:'custom'})):[];
  for(const src of SOURCE.entries.concat(extras)){
    if(!src||!clean(src.jp)||!clean(src.cn))continue;
    const w=Object.assign({},src,{jp:clean(src.jp),cn:clean(src.cn),kana:clean(src.kana)||clean(src.jp),lesson:String(src.lesson||'extra')});
    let record=seen.get(w.jp);
    if(!record){record={jp:w.jp,kana:w.kana,cn:w.cn,pos:w.pos||'',lesson:w.lesson,lessons:[],variants:{}};seen.set(w.jp,record);}
    if(!record.lessons.includes(w.lesson))record.lessons.push(w.lesson);
    const old=record.variants[w.lesson];
    if(!old || (w.source==='教材照片（原文）'&&old.source!=='教材照片（原文）')){
      record.variants[w.lesson]=w;
    }else if(w.source==='教材照片（原文）'&&old.source==='教材照片（原文）'&&w.cn!==old.cn){
      const meanings=old.cn.split('；').map(s=>s.trim());
      if(!meanings.includes(w.cn.trim()))record.variants[w.lesson]=Object.assign({},old,{cn:old.cn+'；'+w.cn});
    }
  }
  const out=Array.from(seen.values());
  out.forEach(w=>{const p=w.variants[w.lesson];if(p){w.kana=p.kana;w.cn=p.cn;w.pos=p.pos;}});
  return out;
}
function forLesson(word,lesson){
  if(lesson&&word.variants[lesson])return Object.assign({},word,word.variants[lesson]);
  return word;
}
function blankState(){
  return {schema:4,custom:[],progress:{},coverage:{},logs:[],settings:{qty:10}};
}
function safeState(input){
  const state=blankState();
  if(!input||typeof input!=='object'||Number(input.schema)!==4)return state;
  if(Array.isArray(input.custom))state.custom=input.custom.filter(w=>w&&clean(w.jp)&&clean(w.cn)).slice(0,5000).map(w=>({
    jp:clean(w.jp),kana:clean(w.kana)||clean(w.jp),cn:clean(w.cn),pos:clean(w.pos)||'单词',lesson:'extra',source:'custom'
  }));
  if(input.progress&&typeof input.progress==='object'&&!Array.isArray(input.progress)){
    for(const jp of Object.keys(input.progress).slice(0,5000)){
      if(jp==='__proto__'||jp==='constructor')continue;
      const p=input.progress[jp]||{};
      state.progress[jp]={streak:Math.max(0,Math.min(100,Number(p.streak)||0)),
        lapses:Math.max(0,Math.min(10000,Number(p.lapses)||0)),
        seen:Math.max(0,Number(p.seen)||0),lastAt:Math.max(0,Number(p.lastAt)||0),
        dueAt:Math.max(0,Number(p.dueAt)||0),lastGrade:p.lastGrade==='good'?'good':'again'};
    }
  }
  if(input.coverage&&typeof input.coverage==='object'&&!Array.isArray(input.coverage)){
    for(const key of Object.keys(input.coverage)){
      if(!/^(all|extra|lesson:[^:]{1,30})$/.test(key)||!Array.isArray(input.coverage[key]))continue;
      state.coverage[key]=Array.from(new Set(input.coverage[key].filter(x=>typeof x==='string'&&x.length<=180))).slice(-5000);
    }
  }
  // Older V4 exports may not contain coverage. Reconstruct what was already introduced.
  if(!Object.keys(state.coverage).length&&Object.keys(state.progress).length){
    const restored=buildLibrary(state.custom);
    for(const w of restored){
      if(!(state.progress[w.jp]&&state.progress[w.jp].seen>0))continue;
      (state.coverage.all||(state.coverage.all=[])).push(w.jp);
      for(const lesson of w.lessons){
        const key=lesson==='extra'?'extra':'lesson:'+lesson;
        (state.coverage[key]||(state.coverage[key]=[])).push(w.jp);
      }
    }
  }
  state.logs=Array.isArray(input.logs)?input.logs.slice(-500):[];
  state.settings.qty=Math.max(1,Math.min(5000,Math.floor(Number(input.settings&&input.settings.qty)||10)));
  return state;
}
function scopeFor(kind,lesson){
  return kind==='lesson'?'lesson:'+String(lesson):(kind==='all'||kind==='extra'?kind:null);
}
function getPool(library,state,kind,lesson,now){
  const at=Number(now)||Date.now();
  if(kind==='lesson')return library.filter(w=>w.lessons.includes(String(lesson)));
  if(kind==='extra')return library.filter(w=>w.lessons.includes('extra'));
  if(kind==='due')return library.filter(w=>state.progress[w.jp]&&state.progress[w.jp].seen>0&&state.progress[w.jp].dueAt<=at).sort((a,b)=>state.progress[a.jp].dueAt-state.progress[b.jp].dueAt);
  if(kind==='weak')return library.filter(w=>state.progress[w.jp]&&state.progress[w.jp].lapses>0&&state.progress[w.jp].streak<3);
  return library.slice();
}
function remaining(pool,state,kind,lesson){
  const scope=scopeFor(kind,lesson);if(!scope)return pool.slice();
  const coverage=new Set(state.coverage[scope]||[]);
  return pool.filter(w=>!coverage.has(w.jp));
}
function markIntroduced(state,jp,kind,lesson){
  const scope=scopeFor(kind,lesson);if(!scope)return;
  if(!Array.isArray(state.coverage[scope]))state.coverage[scope]=[];
  if(!state.coverage[scope].includes(jp))state.coverage[scope].push(jp);
}
function shuffled(items,rng){
  const a=items.slice(), random=rng||Math.random;
  for(let i=a.length-1;i>0;i--){const j=Math.floor(random()*(i+1));const t=a[i];a[i]=a[j];a[j]=t;}
  return a;
}
function selectBatch(pool,state,kind,lesson,qty,rng,explicitRestart){
  let available=remaining(pool,state,kind,lesson);
  const scope=scopeFor(kind,lesson);
  if(scope&&!available.length&&explicitRestart){state.coverage[scope]=[];available=pool.slice();}
  const n=Math.max(1,Math.min(available.length,Math.floor(Number(qty)||10)));
  return kind==='due'?available.slice(0,n):shuffled(available,rng).slice(0,n);
}
function grade(state,jp,remembered,at){
  const now=at==null?Date.now():at;
  const p=state.progress[jp]||{streak:0,lapses:0,seen:0,lastAt:0,dueAt:0,lastGrade:'again'};
  const next=Object.assign({},p,{seen:p.seen+1,lastAt:now,lastGrade:remembered?'good':'again'});
  if(!remembered){next.streak=0;next.lapses++;next.dueAt=now+10*MINUTE;}
  else{next.streak++;next.dueAt=now+INTERVAL_DAYS[Math.min(next.streak-1,6)]*DAY;}
  state.progress[jp]=next;return next;
}
function mergeBackup(local,input){
  if(!input||Number(input.schema)!==4)throw new Error('备份格式不兼容：仅支持网页版 schema 4');
  const incoming=safeState(input), base=safeState(local);
  const combined=new Map(base.custom.map(w=>[w.jp,w]));
  incoming.custom.forEach(w=>{if(!combined.has(w.jp))combined.set(w.jp,w);});
  base.custom=Array.from(combined.values()).slice(0,5000);
  for(const [jp,p] of Object.entries(incoming.progress)){if(!base.progress[jp])base.progress[jp]=p;}
  for(const [key,arr] of Object.entries(incoming.coverage)){
    base.coverage[key]=Array.from(new Set((base.coverage[key]||[]).concat(arr))).slice(-5000);
  }
  base.logs=base.logs.concat(incoming.logs).slice(-500);
  return base;
}
module.exports={SOURCE,lessons,volumeOf,lessonName,posLabel,normalizeAnswer,answerCorrect,buildLibrary,forLesson,
  blankState,safeState,scopeFor,getPool,remaining,markIntroduced,shuffled,selectBatch,grade,mergeBackup};
