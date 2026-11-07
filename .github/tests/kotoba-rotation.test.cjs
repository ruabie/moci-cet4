'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const code=fs.readFileSync('kotoba/app.js','utf8');
const book={lessons:[{id:'1',name:'第一课',cn:'测试课',isPartial:false}],words:Array.from({length:23},(_,i)=>({jp:'詞'+String(i).padStart(2,'0'),kana:'ことば'+i,cn:'词语'+i,lesson:'1',pos:'名词',page:1,source:'textbook'}))};
const storage=new Map();
function bootstrap(){
  const elems=new Map();
  class MockElement{
    constructor(id=''){this.id=id;this.value='';this.textContent='';this.dataset={};this.style={};this.disabled=false;this.children=[];this._html='';this._classes=new Set();this.classList={add:(x)=>this._classes.add(x),remove:(x)=>this._classes.delete(x),toggle:(x,force)=>{const toAdd=force===undefined?!this._classes.has(x):!!force;toAdd?this._classes.add(x):this._classes.delete(x);return toAdd},contains:(x)=>this._classes.has(x)}}
    set innerHTML(value){this._html=String(value);if(this.id==='lessonList'){this.children=[...this._html.matchAll(/data-lesson="([^"]+)"/g)].map(m=>{const e=new MockElement();e.dataset.lesson=m[1];return e})}}
    get innerHTML(){return this._html}
    addEventListener(){}
    appendChild(e){this.children.push(e)}
    setAttribute(){}
    querySelectorAll(selector){return selector==='[data-lesson]'?this.children:[]}
  }
  const el=id=>{if(!elems.has(id))elems.set(id,new MockElement(id));return elems.get(id)};
  const document={getElementById:el,querySelectorAll:()=>[],createElement:()=>new MockElement(),addEventListener(){},body:new MockElement('body')};
  const context={window:{KOTOBA_BOOK:book,scrollTo(){}},document,navigator:{},location:{protocol:'http:'},localStorage:{getItem:k=>storage.get(k)??null,setItem:(k,v)=>storage.set(k,v)},console,setTimeout:()=>0,clearTimeout(){}};
  vm.runInNewContext(code,context,{filename:'kotoba/app.js'});
  return {el};
}
function runRound(runtime,mode='lesson'){
  const {el}=runtime;
  if(mode==='lesson'){
    el('openLessons').onclick();
    const lesson=el('lessonList').querySelectorAll('[data-lesson]')[0];assert.ok(lesson,'Lesson must be selectable');
    lesson.onclick();
  }else{el('openAll').onclick()}
  el('startSession').onclick();
  const size=Number((el('studyPage').textContent.split('/')[1]||'').trim());
  assert.ok(size>0&&size<=23,'Batch length should be reasonable');
  const words=[];
  for(let i=0;i<size;i++){
    words.push(el('cardWord').textContent);
    el('nextCard').onclick();
  }
  assert.equal(new Set(words).size,words.length,'No duplicates within a batch');
  return words;
}
let ui=bootstrap();
const first=runRound(ui);
ui=bootstrap(); // reload page and verify persistent coverage
const second=runRound(ui);
const third=runRound(ui);
const fourth=runRound(ui);
assert.deepEqual([first.length,second.length,third.length,fourth.length],[10,10,3,10]);
assert.equal(new Set([...first,...second,...third]).size,23,'All 23 words must be covered before repetition');
assert.equal(first.some(w=>second.includes(w)),false,'Second batch must not overlap first');
assert.equal(first.some(w=>third.includes(w)),false,'Third batch must not overlap first');
assert.equal(second.some(w=>third.includes(w)),false,'Third batch must not overlap second');
assert.equal(new Set([...first,...second,...third,...fourth]).size,23,'New cycle may repeat after full coverage');
const saved=JSON.parse(storage.get('kotoba_pwa_v4'));
assert.equal(saved.settings.qty,10,'Last short batch must not reduce preferred batch size');
assert.equal(saved.coverage['lesson:1'].length,10,'Fresh cycle must start its own coverage');
assert.deepEqual(Object.keys(saved.progress),[],'Simply viewing cards must not change memory grades');
// Full collection also rotates separately without repeating before exhaustion.
storage.clear();
ui=bootstrap();
const a=runRound(ui,'all'),b=runRound(ui,'all'),c=runRound(ui,'all');
assert.equal(new Set([...a,...b,...c]).size,23,'Full-library mode must also cover all words');
console.log('Kotoba rotation regression passed: lesson 10/10/3/10, persistence, preferred qty, SRS isolation, and full-library coverage.');
