'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const read=p=>fs.readFileSync(p,'utf8');
const js=read('kotoba/app.js'),html=read('kotoba/index.html'),css=read('kotoba/styles.css'),sw=read('kotoba/sw.js');
assert.match(html,/id="openDirect"/);
assert.match(html,/id="directFromSetup"/);
assert.match(html,/id="directSetup"/);
assert.match(html,/id="directScope"/);
assert.match(html,/id="directQty"/);
assert.match(html,/id="chooseBack"/);
assert.match(html,/id="testForgot"/);
assert.match(html,/id="testRemember"/);
assert.match(html,/styles\.css\?v=7\.2/);
assert.match(html,/app\.js\?v=7\.2/);
assert.match(sw,/kotoba-v7\.3/);
assert.match(css,/V7\.2: Direct recall controls/);
assert.doesNotMatch(css,/\.ios-tabbar/);
assert.match(html,/SLOW LEARNING \/ DEEP MEMORY/);
const study=html.split('<section id="study"')[1].split('<section id="test"')[0];
assert.ok(study.includes('id="cardPos"'),'Learning POS still shown');
assert.ok(!html.split('<section id="test"')[1].split('</section>')[0].includes('id="cardPos"'),'No POS quiz');

const school={
  lessons:[{id:'1',name:'第一课',cn:'第一课',isPartial:false},{id:'12',name:'第十二课',cn:'十二课',isPartial:false}],
  words:[
    ...Array.from({length:14},(_,i)=>({jp:'詞'+i,kana:'ことば'+i,cn:'释义'+i,lesson:'1',source:'textbook',pos:'名',page:1})),
    ...Array.from({length:11},(_,i)=>({jp:'語'+i,kana:'ご'+i,cn:'意思'+i,lesson:'12',source:'textbook',pos:'名',page:1})),
    {jp:'預かる',kana:'あずかる',cn:'保管',lesson:'1',source:'textbook',pos:'他五',page:1},
    {jp:'預かる',kana:'あずかる',cn:'承蒙',lesson:'12',source:'textbook',pos:'他五',page:1}
  ]
};
const extra=[{jp:'のびる',kana:'のびる',cn:'伸长',lesson:'extra',source:'chat',pos:'自一',page:0}];
const expected=new Map(school.words.map(w=>[w.jp,w.jp]));
const wordsByCN=new Map([...school.words,...extra].map(w=>[w.cn,w.jp]));
let memory=new Map();
class MockElement {
 constructor(id=''){
  this.id=id;this.value='';this.textContent='';this.dataset={};this.style={};this.disabled=false;this.children=[];this.options=[];this._html='';
  this._set=new Set();
  this.classList={add:x=>this._set.add(x),remove:x=>this._set.delete(x),contains:x=>this._set.has(x),toggle:(x,force)=>{const enabled=force===undefined?!this._set.has(x):!!force;enabled?this._set.add(x):this._set.delete(x);return enabled}};
 }
 set innerHTML(v){
  this._html=String(v);
  if(this.id==='libLesson'||this.id==='directScope'){
   this.options=[...this._html.matchAll(/<option value="([^"]+)"/g)].map(m=>({value:m[1]}));
  }
  if(this.id==='lessonList'){
   this.children=[...this._html.matchAll(/data-lesson="([^"]+)"/g)].map(m=>{const e=new MockElement();e.dataset.lesson=m[1];return e});
  }
 }
 get innerHTML(){return this._html;}
 setAttribute(){}
 addEventListener(name,fn){this['on'+name]=fn}
 appendChild(e){this.children.push(e)}
 querySelectorAll(selector){return selector==='[data-lesson]'?this.children:[]}
}
function boot(){
 const elems=new Map();
 const el=id=>{if(!elems.has(id))elems.set(id,new MockElement(id));return elems.get(id)};
 const modes=['cn-jp','jp-cn'].map(mode=>{const e=new MockElement();e.dataset.mode=mode;return e});
 const qty=['10','20'].map(n=>{const e=new MockElement();e.dataset.directQty=n;return e});
 const document={
  getElementById:el,body:new MockElement('body'),createElement:()=>new MockElement(),
  querySelectorAll:selector=>selector==='[data-mode]'?modes:selector==='[data-direct-qty]'?qty:[],addEventListener(){}
 };
 const context={window:{KOTOBA_BOOK:JSON.parse(JSON.stringify(school)),KOTOBA_EXTRAS:JSON.parse(JSON.stringify(extra)),scrollTo(){}},
  document,localStorage:{getItem:k=>memory.get(k)??null,setItem:(k,v)=>memory.set(k,v)},
  navigator:{},location:{protocol:'http:'},setTimeout:()=>0,clearTimeout(){},console};
 vm.runInNewContext(js,context,{filename:'kotoba/app.js'});
 const active=id=>!el(id).classList.contains('hidden');
 const saved=()=>JSON.parse(memory.get('kotoba_pwa_v4'));
 return {el,modes,qty,active,saved};
}
const booted=boot(),{el,modes,active,saved}=booted;
el('openDirect').onclick();
assert.ok(active('directSetup'),'Home Direct Recall must skip learning');
assert.equal(el('directPoolSize').textContent,27,'All library entries include course words and extra once');
assert.equal(Number(el('directQty').value),10);
assert.equal(el('directScope').value,'all');
el('directQty').value='20';
el('directQty').onchange();
el('startDirectTest').onclick();
assert.ok(active('choose'));
assert.equal(active('study'),false,'Direct recall must bypass study stage');
el('chooseBack').onclick();
assert.ok(active('directSetup'),'Back from direction selection returns direct setup');
el('startDirectTest').onclick();
modes[0].onclick(); // Chinese to Japanese
assert.ok(active('test'));
assert.ok(el('testCount').textContent.endsWith(' / 20'),'Custom 20 questions applied');
const seen=new Set();
for(let i=0;i<20;i++){
 const cn=el('questionWord').textContent;
 assert.ok(wordsByCN.has(cn),'No made-up translation in quiz: '+cn);
 const jp=wordsByCN.get(cn);
 assert.ok(!seen.has(jp),'No duplicate questions in initial sample');
 seen.add(jp);
 el('answer').value=jp;el('answerBtn').onclick();
 assert.equal(el('testRemember').disabled,false,'Correct answer enables remembered');
 el('testRemember').onclick();
}
assert.ok(active('done'),'Quiz ends after 20 recall questions');
assert.equal(el('score').textContent,'100%');
assert.equal(saved().logs.at(-1).direct,true);
assert.equal(saved().logs.at(-1).total,20);
assert.equal(Object.keys(saved().coverage).length,0,'Direct quiz must not consume study coverage');
assert.ok(el('continueSession').classList.contains('hidden'),'Direct quiz must not claim next study batch');
assert.equal(Object.keys(saved().progress).length,20,'Direct recall still schedules SRS based on judgments');

// By-lesson direct recall: selection keeps each course's textbook meaning and all-words quantity.
const u2=boot();u2.el('openLessons').onclick();
const card=u2.el('lessonList').querySelectorAll('[data-lesson]').find(e=>e.dataset.lesson==='12');
assert.ok(card);card.onclick();assert.ok(u2.active('setup'));
u2.el('directFromSetup').onclick();
assert.ok(u2.active('directSetup'));
assert.equal(u2.el('directScope').value,'lesson:12');
assert.equal(u2.el('directPoolSize').textContent,12);
u2.el('directAllQty').onclick();
assert.equal(Number(u2.el('directQty').value),12);
u2.el('startDirectTest').onclick();
u2.modes[1].onclick(); // Japanese to Chinese, lesson-specific gloss
let found=false;
for(let i=0;i<12;i++){
 const jp=u2.el('questionWord').textContent;
 if(jp==='預かる')found=true;
 const correct=jp==='預かる'?'承蒙':'意思'+jp.slice(1);
 u2.el('answer').value=correct;u2.el('answerBtn').onclick();
 assert.equal(u2.el('testRemember').disabled,false,'Expected lesson-specific meaning '+jp);
 u2.el('testRemember').onclick();
}
assert.ok(found,'Must include every word in course when selecting all');
assert.ok(u2.active('done'));
assert.equal(u2.saved().logs.at(-1).lesson,'12');
assert.equal(u2.saved().logs.at(-1).direct,true);
assert.equal(Object.keys(u2.saved().coverage).length,0,'Lesson quiz does not mark words studied');

// Forgetting a word in direct recall must still schedule another exposure, and never override 10 min review with a short-term correct repeat.
const u3=boot();u3.el('openDirect').onclick();
u3.el('directScope').value='extra';u3.el('directScope').onchange();
assert.equal(u3.el('directPoolSize').textContent,1);
u3.el('startDirectTest').onclick();u3.modes[0].onclick();
u3.el('skipAnswer').onclick();u3.el('testForgot').onclick();
assert.ok(u3.active('test'),'Forgotten item should reappear in same session');
u3.el('answer').value='のびる';u3.el('answerBtn').onclick();u3.el('testRemember').onclick();
assert.ok(u3.active('done'));
const p=u3.saved().progress['のびる'];
assert.equal(p.lastGrade,'again');
assert.equal(p.lapses,1);
assert.ok(p.dueAt>Date.now(),'Weak word keeps review due in future');
assert.equal(u3.saved().logs.at(-1).repeat,1);
assert.equal(Object.keys(u3.saved().coverage).length,0);
console.log('KOTOBA DIRECT QUIZ PASS: 20 from full library, no repeats, lesson 12 meanings, all mode, weak-word repeats, no coverage consumption, independent original UI.');
