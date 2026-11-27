'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const read=p=>fs.readFileSync(p,'utf8');
const dataContext={window:{}};
vm.createContext(dataContext);
for(const p of ['kotoba/book-data.js','kotoba/vocab-03-page08.js','kotoba/vocab-04.js','kotoba/vocab-05.js','kotoba/vocab-06-07.js','kotoba/vocab-13.js','kotoba/vocab-14.js','kotoba/vocab-15.js','kotoba/vocab-16.js'])vm.runInContext(read(p),dataContext,{filename:p});
const source=dataContext.window.KOTOBA_BOOK;
const added=dataContext.window.KOTOBA_SUPPLEMENTS;
assert.ok(Array.isArray(source.words)&&source.words.length>=250,'Original textbook corpus retained');
assert.equal(added.length,667,'All supplementary entries must be present including lessons 6/7');
const lessonCounts={'3':18,'4':61,'5':92,'6':36,'7':88,'13':118,'14':37,'15':79,'16':138};
for(const [lesson,count] of Object.entries(lessonCounts))assert.equal(added.filter(x=>x.lesson===lesson).length,count,'unexpected number of '+lesson+' entries');
const printed=new Set();
for(const w of added){
  for(const key of ['lesson','section','page','jp','kana','pos','cn','source'])assert.ok(w[key],w.jp+' missing '+key);
  const identity=[w.lesson,w.page,w.jp,w.cn].join('|');
  assert.ok(!printed.has(identity),'Duplicate photograph entry '+identity);
  printed.add(identity);
}
const byJP=(lesson,jp)=>added.filter(x=>x.lesson===lesson&&x.jp===jp);
assert.equal(byJP('6','架け橋')[0].cn,'桥梁');
assert.equal(byJP('6','不幸')[0].pos,'名・ナ形');
assert.equal(byJP('6','転々')[0].cn,'转来转去；翻来覆去');
assert.equal(byJP('6','愛読')[0].kana,'あいどく');
assert.equal(byJP('7','頷く')[0].kana,'うなずく');
assert.equal(byJP('7','独り善がり')[0].cn,'自以为是');
assert.equal(byJP('7','以心伝心')[0].cn,'心领神会，心意相通');
assert.equal(byJP('7','栗餅')[0].cn,'板栗糯米饼');
assert.equal(byJP('7','孝文化')[0].cn,'孝敬文化，孝文化');
assert.equal(added.filter(x=>x.lesson==='7'&&x.page===20).length,4,'Lesson 8 words must not leak into lesson 7');
assert.equal(byJP('7','雨傘').length,0,'Lesson 8 not included');
assert.equal(byJP('13','メニュー')[0].cn,'菜单');
assert.equal(byJP('13','鍵')[0].cn,'关键');
assert.deepEqual(Array.from(byJP('13','上げる').map(x=>x.cn)),['举，抬','发出（声音）']);
assert.equal(byJP('14','泣く')[0].cn,'苦恼，发愁，伤心');
assert.equal(byJP('15','新入部員')[0].kana,'しんにゅうぶいん');
assert.equal(byJP('15','預かる')[0].cn,'（代人）保管，收存');
assert.equal(byJP('16','預かる')[0].cn,'承蒙');
assert.equal(byJP('16','住民票')[0].cn,'居民卡');
assert.equal(byJP('16','点')[0].cn,'（某一）点，（某一）方面');
const html=read('kotoba/index.html');
const studyHTML=html.split('<section id="study"')[1].split('<section id="test"')[0];
const testHTML=html.split('<section id="test"')[1];
assert.ok(studyHTML.includes('class="card-pos" id="cardPos"'),'POS must appear in full-screen study page');
assert.ok(studyHTML.indexOf('id="cardPos"')>studyHTML.indexOf('id="cardReveal"'),'POS should be shown with the revealed meaning');
assert.ok(!testHTML.includes('id="cardPos"'),'No POS in assessment page');
const assetRefs=html.split('"./').slice(1).map(x=>x.split('"')[0]);
const validVersion=ref=>{
  const v=ref.split('?v=')[1];
  return !!v&&v.split('.').every(part=>part.length>0&&[...part].every(ch=>ch>='0'&&ch<='9'));
};
for(const file of ['book-data.js','vocab-03-page08.js','vocab-04.js','vocab-05.js','vocab-06-07.js','vocab-13.js','vocab-14.js','vocab-15.js','vocab-16.js','extra-words.js','app.js','styles.css']){
  assert.ok(assetRefs.some(ref=>ref.startsWith(file+'?v=')&&validVersion(ref)),
    'Missing versioned script or stylesheet '+file);
}
const storage=new Map();
class MockElement{
  constructor(id=''){
    this.id=id;this.value='';this.textContent='';this.dataset={};this.style={};this.disabled=false;this.children=[];this.options=[];this._html='';this._classes=new Set();
    this.classList={
      add:x=>this._classes.add(x),remove:x=>this._classes.delete(x),
      toggle:(x,force)=>{const t=force===undefined?!this._classes.has(x):!!force;t?this._classes.add(x):this._classes.delete(x);return t},
      contains:x=>this._classes.has(x)
    };
  }
  set innerHTML(v){
    this._html=String(v);
    if(this.id==='libLesson')this.options=[...this._html.matchAll(/<option value="([^"]+)"/g)].map(m=>({value:m[1]}));
    if(this.id==='lessonList')this.children=[...this._html.matchAll(/data-lesson="([^"]+)"/g)].map(m=>{const e=new MockElement();e.dataset.lesson=m[1];return e});
  }
  get innerHTML(){return this._html}
  addEventListener(){}
  setAttribute(){}
  appendChild(e){this.children.push(e)}
  querySelectorAll(selector){return selector==='[data-lesson]'?this.children:[]}
}
function boot(){
  const elements=new Map();const el=id=>{if(!elements.has(id))elements.set(id,new MockElement(id));return elements.get(id)};
  const document={getElementById:el,querySelectorAll:()=>[],createElement:()=>new MockElement(),addEventListener(){},body:new MockElement('body')};
  const window={KOTOBA_BOOK:source,KOTOBA_SUPPLEMENTS:added,scrollTo(){}};
  const sandbox={window,document,navigator:{},location:{protocol:'http:'},localStorage:{getItem:k=>storage.get(k)??null,setItem:(k,v)=>storage.set(k,v)},console,clearTimeout(){},setTimeout:()=>0};
  vm.runInNewContext(read('kotoba/app.js'),sandbox,{filename:'kotoba/app.js'});
  return el;
}
function course(el,id){
  el('openLessons').onclick();
  const element=el('lessonList').querySelectorAll('[data-lesson]').find(e=>e.dataset.lesson===id);
  assert.ok(element,'Lesson '+id+' must be selectable');
  element.onclick();
  el('qty').value=999;
  el('startSession').onclick();
  const count=Number(el('studyPage').textContent.split('/')[1].trim());
  const result=new Map();
  for(let i=0;i<count;i++){
    const jp=el('cardWord').textContent,cn=el('cardCn').textContent,pos=el('cardPos').textContent,kana=el('cardKana').textContent;
    assert.ok(jp&&cn&&pos&&kana,'All study card fields must be filled for '+jp);
    assert.ok(pos.startsWith('词性 · '),'Visible POS label missing');
    result.set(jp,{cn,pos,kana});
    el('nextCard').onclick();
  }
  return result;
}
const el=boot();
const c3=course(el,'3');
const c4=course(el,'4');
const c5=course(el,'5');
const c6=course(el,'6');
const c7=course(el,'7');
const c13=course(el,'13');
const c14=course(el,'14');
const c15=course(el,'15');
const c16=course(el,'16');
assert.ok(c4.size===61&&c5.size===92&&c6.size===36&&c7.size===88,'Lesson 4–7 photograph corpus incomplete');
assert.equal(c4.get('異なる').cn,'不同，不一样');
assert.equal(c4.get('物産').cn,'物产；特产');
assert.equal(c4.get('海水浴').cn,'海水浴');
assert.equal(c4.get('スポーツサークル').cn,'体育社团');
assert.equal(c5.get('戦国').cn,'战国');
assert.equal(c5.get('幕藩').cn,'幕藩（体制）');
assert.equal(c5.get('明').kana,'みん');
assert.equal(c5.get('羅針盤').cn,'罗盘，指南针');
assert.equal(c5.get('話が弾む').cn,'聊得起劲');
assert.equal(c6.get('著作').cn,'著作');
assert.equal(c6.get('観察記').kana,'かんさつき');
assert.equal(c6.get('悔しい').cn,'后悔，内疚');
assert.equal(c7.get('末').cn,'最末；最小');
assert.equal(c7.get('あっという間').cn,'一瞬间');
assert.equal(c7.get('帰省').cn,'回老家');
assert.equal(c7.get('世代間').cn,'隔代');
assert.equal(c7.get('孝文化').cn,'孝敬文化，孝文化');
assert.equal(c3.get('立春').cn,'立春');
assert.ok(c13.size>=110&&c14.size>=35&&c15.size>=70&&c16.size>=125,'Lesson corpus unexpectedly small');
assert.equal(c13.get('メニュー').cn,'菜单','Previous approximate gloss must be replaced by new photo');
assert.ok(c13.get('上げる').cn.includes('举，抬')&&c13.get('上げる').cn.includes('发出（声音）'),'Multiple original senses retained');
assert.equal(c15.get('預かる').cn,'（代人）保管，收存');
assert.equal(c16.get('預かる').cn,'承蒙','Cross-lesson meaning must follow that lesson photo');
assert.equal(c13.get('信頼').pos,'词性 · 名词 / 他动词·サ变','Book POS must be visible and translated');
assert.equal(c15.get('新入部員').kana,'しんにゅうぶいん');
assert.equal(c16.get('住民票').cn,'居民卡');
const totalUnique=new Set([...source.words,...added].map(x=>x.jp));
assert.equal(Number(el('totalWords').textContent),totalUnique.size,'Large library must dedupe words');
console.log('Catalog V7 verified: original '+source.words.length+', photo records '+added.length+
 ', unique total '+totalUnique.size+', course cards '+[c4.size,c5.size,c6.size,c7.size,c13.size,c14.size,c15.size,c16.size].join('/')+
 ', source Chinese gloss, POS study-only, cross-lesson meanings and prior words preserved.');
