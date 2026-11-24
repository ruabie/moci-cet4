'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=process.cwd();
const html=fs.readFileSync('kotoba-ios/index.html','utf8');
const css=fs.readFileSync('kotoba-ios/ios.css','utf8');
const app=fs.readFileSync('kotoba-ios/app.js','utf8');
const sw=fs.readFileSync('kotoba-ios/sw.js','utf8');
const manifest=JSON.parse(fs.readFileSync('kotoba-ios/manifest.webmanifest','utf8'));
const read=p=>fs.readFileSync(p,'utf8');
assert.match(html,/class="ios-tabbar"/);
for(const tab of ['home','lessons','library','stats'])assert.match(html,new RegExp('data-tab="'+tab+'"'));
assert.match(html,/href="\.\.\/kotoba\/"/);
assert.match(html,/href="\.\/ios\.css\?v=1\.0"/);
assert.match(html,/id="cardPos"/);
assert.ok(!html.slice(html.indexOf('<section id="study"'),html.indexOf('<section id="test"')).includes('id="testForgot"'),'Study must not grade');
assert.ok(html.slice(html.indexOf('<section id="test"')).includes('id="testForgot"'),'Test must keep grading');
assert.match(app,/const KEY='kotoba_ios_preview_v1'/);
assert.match(app,/original=STORAGE\.get\('kotoba_pwa_v4'\)/);
assert.doesNotMatch(app,/const KEY='kotoba_pwa_v4'/);
assert.match(sw,/ios-kotoba-preview-v1/);
assert.doesNotMatch(sw,/key\.startsWith\('kotoba-'\)/);
assert.equal(manifest.start_url,'./');
assert.equal(manifest.scope,'./');
for(const expected of ['.ios-tabbar','.stats-strip','.entry-card','.lesson-card','.word-stage','.test-immersion','.card-pos','env(safe-area-inset-bottom)'])
 assert.ok(css.includes(expected),'iOS theme missing '+expected);
const paths=[...html.matchAll(/<(?:link|script)[^>]+(?:href|src)="([^"]+)"/g)].map(m=>m[1]);
for(const ref of paths){
 if(!ref.startsWith('./')&&!ref.startsWith('../'))continue;
 const file=path.resolve('kotoba-ios',ref.split('?')[0]);
 assert.ok(file.startsWith(root+'/'),'Unsafe relative asset '+ref);
 assert.ok(fs.existsSync(file),'Missing asset: '+ref);
}
const data={window:{}};
vm.createContext(data);
for(const script of [...html.matchAll(/<script src="([^"]+)"/g)].map(m=>m[1]).filter(x=>!x.includes('./app.js')))
 vm.runInContext(read(path.resolve('kotoba-ios',script.split('?')[0])),data,{filename:script});
assert.ok(data.window.KOTOBA_BOOK?.words?.length>250,'Book data not loaded');
assert.ok(data.window.KOTOBA_SUPPLEMENTS?.length>=500,'Supplementary lessons not loaded');
class Elem{
 constructor(id=''){this.id=id;this.textContent='';this.value='';this.style={};this.dataset={};this.children=[];this.options=[];this.disabled=false;this._html='';this._set=new Set();this.classList={add:s=>this._set.add(s),remove:s=>this._set.delete(s),contains:s=>this._set.has(s),toggle:(s,force)=>{let on=force===undefined?!this._set.has(s):!!force;on?this._set.add(s):this._set.delete(s);return on}}}
 addEventListener(){}setAttribute(){} appendChild(e){this.children.push(e)}
 set innerHTML(v){this._html=String(v);if(this.id==='libLesson'){this.options=[...this._html.matchAll(/<option value="([^"]+)"/g)].map(m=>({value:m[1]}));}if(this.id==='lessonList'){this.children=[...this._html.matchAll(/data-lesson="([^"]+)"/g)].map(m=>{const e=new Elem();e.dataset.lesson=m[1];return e})}}
 get innerHTML(){return this._html}
 querySelectorAll(s){return s==='[data-lesson]'?this.children:[]}
}
const elements=new Map(),el=id=>{if(!elements.has(id))elements.set(id,new Elem(id));return elements.get(id)};
const storage=new Map();
const official={schema:4,custom:[],progress:{'鍋':{seen:2,lastGrade:'good',streak:1,dueAt:0}},coverage:{all:['鍋']},logs:[],settings:{qty:10}};
const baseline=JSON.stringify(official);storage.set('kotoba_pwa_v4',baseline);
const doc={getElementById:el,querySelectorAll:()=>[],createElement:()=>new Elem(),addEventListener(){},body:new Elem('body')};
const win={...data.window,scrollTo(){}};
vm.runInNewContext(app,{document:doc,window:win,navigator:{},location:{protocol:'http:'},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},console,Date,Math,setTimeout:()=>0,clearTimeout(){}},{filename:'kotoba-ios/app.js'});
assert.ok(Number(el('totalWords').textContent)>700,'Full corpus missing');
el('openLessons').onclick();
const lessonCards=el('lessonList').querySelectorAll('[data-lesson]');
assert.ok(lessonCards.some(x=>x.dataset.lesson==='4'),'Lesson 4 missing');
assert.ok(lessonCards.some(x=>x.dataset.lesson==='16'),'Lesson 16 missing');
const first=lessonCards.find(x=>x.dataset.lesson==='4');
first.onclick();el('startSession').onclick();
assert.ok(el('cardWord').textContent,'Flashcard failed to render');
assert.equal(storage.get('kotoba_pwa_v4'),baseline,'Preview modified official learning records');
assert.ok(storage.get('kotoba_ios_preview_v1'),'Preview failed to save its own progress');
assert.ok(!/testForgot/.test(css),'Do not inject assessment controls in study stylesheet');
console.log('iOS PREVIEW PASS: source assets, lesson data, navigation, full-screen learning, assessment separation, and read-only source progress');
