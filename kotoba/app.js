(() => {
  'use strict';
  const KEY='kotoba_pwa_v4'; // preserve persisted V4 records; V5 changes UI only
  const OLD_KEYS=['kotoba_pwa_v3','kotoba_v2_ins','kotoba_v1'];
  const DAY=24*60*60*1000, MINUTE=60*1000;
  const BOOK=window.KOTOBA_BOOK;
  if(!BOOK || !Array.isArray(BOOK.words)) {document.body.innerHTML='词库数据未能加载，请刷新网页。';return;}
  const $=id=>document.getElementById(id);
  const SUPPLEMENT_WORDS=Array.isArray(window.KOTOBA_SUPPLEMENTS)?window.KOTOBA_SUPPLEMENTS.filter(w=>w&&w.jp&&w.cn&&w.lesson):[];
  for(const entry of [
    {id:'14',name:'研修',cn:'研修',pages:'38–39',isPartial:false},
    {id:'15',name:'ゼミ',cn:'研讨课',pages:'39–42',isPartial:false},
    {id:'16',name:'忘年会',cn:'忘年会',pages:'42–46',isPartial:true}
  ]){if(!BOOK.lessons.some(x=>x.id===entry.id))BOOK.lessons.push(entry);}
  const thirteen=BOOK.lessons.find(x=>x.id==='13');
  if(thirteen&&SUPPLEMENT_WORDS.some(w=>w.lesson==='13')){thirteen.pages='34–38';thirteen.isPartial=false;}
  BOOK.lessons.sort((a,b)=>Number(a.id)-Number(b.id));
  const BOOK_WORDS=[...BOOK.words,...SUPPLEMENT_WORDS].map(w=>({...w}));
  // Maintained from this chat: separate source, shared memory progress with the textbook.
  const CHAT_WORDS=(Array.isArray(window.KOTOBA_EXTRAS)?window.KOTOBA_EXTRAS:[])
    .filter(w=>w&&w.jp&&w.cn)
    .map(w=>({...w,lesson:'extra',section:'聊天课外词',source:'chat'}));
  const COURSE=new Map(BOOK.lessons.map(x=>[x.id,x]));
  const STORAGE={get(k){try{return JSON.parse(localStorage.getItem(k))}catch{return null}},set(k,x){try{localStorage.setItem(k,JSON.stringify(x));return true}catch{return false}}};
  const clean=s=>String(s??'').trim().slice(0,180);
  const norm=s=>String(s??'').normalize('NFKC').trim().toLowerCase().replace(/[\s　。、，,.!?！？・（）()「」『』]/g,'');
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const uniq=arr=>[...new Set(arr)];
  const randomize=a=>{let c=[...a];for(let j=c.length-1;j>0;j--){let k=Math.floor(Math.random()*(j+1));[c[j],c[k]]=[c[k],c[j]];}return c;};
  const dateText=ts=>new Date(ts).toLocaleString('zh-CN',{month:'numeric',day:'numeric',hour:'2-digit',minute:'2-digit'});
  // New-word coverage is independent of memory ratings and their spaced-repetition schedule.
  const coverageScope=(type,lesson)=>type==='lesson'?'lesson:'+lesson:(type==='all'||type==='extra'?type:null);
  function normalizeCoverage(raw){
    const out={};
    if(!raw||typeof raw!=='object'||Array.isArray(raw))return out;
    for(const [scope,words] of Object.entries(raw)){
      if(!(/^(all|extra|lesson:[^:]{1,30})$/.test(scope))||!Array.isArray(words))continue;
      out[scope]=uniq(words.filter(jp=>typeof jp==='string'&&jp.length<=180)).slice(-5000);
    }
    return out;
  }
  function coverageFromProgress(words,progress){
    const raw={};
    for(const w of words)if((progress[w.jp]?.seen||0)>0){
      for(const scope of ['all','lesson:'+w.lesson]){
        (raw[scope]||(raw[scope]=[])).push(w.jp);
      }
    }
    return normalizeCoverage(raw);
  }
  function remainingNewWords(words,scope){
    if(!scope)return words;
    const covered=new Set(db.coverage[scope]||[]);
    return words.filter(w=>!covered.has(w.jp));
  }
  function markIntroduced(jp,kind,lesson){
    const scope=coverageScope(kind,lesson);
    if(!scope)return;
    const covered=db.coverage[scope]||(db.coverage[scope]=[]);
    if(!covered.includes(jp)){covered.push(jp);save();}
  }
  function normalizeProgress(p){return {streak:Math.max(0,Math.min(100,Number(p?.streak)||0)),lapses:Math.max(0,Math.min(10000,Number(p?.lapses)||0)),dueAt:Math.max(0,Number(p?.dueAt)||0),lastAt:Math.max(0,Number(p?.lastAt)||0),seen:Math.max(0,Number(p?.seen)||0),lastGrade:p?.lastGrade==='good'?'good':'again'};}
  function migrate(){
    let original=STORAGE.get(KEY);
    if(original && original.schema===4){
      const custom=Array.isArray(original.custom)?original.custom.filter(w=>w&&clean(w.jp)&&clean(w.cn)).slice(0,5000).map(w=>({jp:clean(w.jp),kana:clean(w.kana)||clean(w.jp),cn:clean(w.cn),pos:clean(w.pos)||'单词',lesson:'extra',section:'自行添加',source:'custom'})):[];
      const progress=original.progress&&typeof original.progress==='object'?Object.fromEntries(Object.entries(original.progress).map(([k,v])=>[k,normalizeProgress(v)])):{};
      const coverage=original.coverage&&typeof original.coverage==='object'?normalizeCoverage(original.coverage):coverageFromProgress([...BOOK_WORDS,...custom],progress);
      return {schema:4,custom,progress,coverage,logs:Array.isArray(original.logs)?original.logs.slice(-500):[],settings:{qty:Number(original.settings?.qty)||10,voiceURI:original.settings?.voiceURI||''}};
    }
    const result={schema:4,custom:[],progress:{},coverage:{},logs:[],settings:{qty:10}};
    const exists=new Set(BOOK_WORDS.map(w=>w.jp));
    for(const key of OLD_KEYS){
      const raw=STORAGE.get(key);
      if(!raw||!Array.isArray(raw.words))continue;
      const idToJP=new Map();
      for(const w of raw.words.slice(0,5000)){
        if(!w||!clean(w.jp)||!clean(w.cn))continue;
        idToJP.set(String(w.id),clean(w.jp));
        if(!exists.has(clean(w.jp))){result.custom.push({jp:clean(w.jp),kana:clean(w.kana)||clean(w.jp),cn:clean(w.cn),pos:clean(w.pos)||'单词',lesson:'extra',section:'旧词库',source:'custom'});exists.add(clean(w.jp));}
      }
      if(raw.mistakes&&typeof raw.mistakes==='object'){
        Object.entries(raw.mistakes).forEach(([id,p])=>{let word=idToJP.get(String(id));if(word&&(p?.cnjp||p?.jpcn))result.progress[word]={streak:0,lapses:1,seen:1,lastAt:Date.now(),dueAt:Date.now()-1,lastGrade:'again'};});
      }
      if(Array.isArray(raw.wrong))raw.wrong.forEach(id=>{let word=idToJP.get(String(id));if(word)result.progress[word]={streak:0,lapses:1,seen:1,lastAt:Date.now(),dueAt:Date.now()-1,lastGrade:'again'};});
      if(Array.isArray(raw.logs))result.logs=raw.logs.slice(-500);
      break;
    }
    result.coverage=coverageFromProgress([...BOOK_WORDS,...result.custom],result.progress);
    return result;
  }
  let db=migrate();
  if(!STORAGE.set(KEY,db))console.warn('本地存储可能不可用');
  // A Japanese spelling has one shared memory record but can belong to several lessons.
  // Preserve each lesson's printed gloss, including distinct meanings for the same verb.
  const allWords=()=>{
    const map=new Map();
    for(const source of [...BOOK_WORDS,...CHAT_WORDS,...db.custom]){
      const w={...source},old=map.get(w.jp);
      if(!old){
        map.set(w.jp,{...w,lessons:[w.lesson],lessonVariants:{[w.lesson]:{...w}}});
        continue;
      }
      if(!old.lessons.includes(w.lesson))old.lessons.push(w.lesson);
      const before=old.lessonVariants[w.lesson];
      const isPhoto=w.source==='教材照片（原文）';
      if(!before||(isPhoto&&before.source!=='教材照片（原文）')){
        old.lessonVariants[w.lesson]={...w}; // new photo supersedes old approximate gloss
      }else if(isPhoto&&before.source==='教材照片（原文）'&&before.cn!==w.cn){
        const senses=before.cn.split('；').map(x=>x.trim());
        if(!senses.includes(w.cn.trim()))old.lessonVariants[w.lesson]={...before,cn:before.cn+'；'+w.cn};
      }
    }
    for(const w of map.values()){
      const primary=w.lessonVariants[w.lesson]||w;
      w.kana=primary.kana;w.cn=primary.cn;w.pos=primary.pos;
      w.page=primary.page;w.section=primary.section;w.source=primary.source;
    }
    return [...map.values()];
  };
  let activeLesson=null;
  const wordByJP=jp=>{
    const w=allWords().find(x=>x.jp===jp);
    if(!w)return null;
    const lessonWord=activeLesson&&w.lessonVariants[activeLesson];
    return lessonWord?{...w,...lessonWord,lessons:w.lessons,lessonVariants:w.lessonVariants}:w;
  };
  const posLabel=tag=>{
    const dictionary={'名':'名词','副':'副词','イ形':'い形容词','ナ形':'な形容词',
      '他五':'他动词·五段','自五':'自动词·五段','自他五':'自／他动词·五段',
      '他上一':'他动词·一段','他下一':'他动词·一段','自上一':'自动词·一段',
      '自下一':'自动词·一段','自サ':'自动词·サ变','他サ':'他动词·サ变',
      '自他サ':'自／他动词·サ变','取り立て助':'提示助词','格助':'格助词',
      '终助':'终助词','接续':'接续词','接頭':'接头词','接尾':'接尾词',
      '连语':'固定表达','连体':'连体词','代':'代词','感':'感叹词',
      '助数':'量词','表达':'固定表达'};
    if(!tag)return '单词';
    // Older saved items already have Chinese parts of speech.
    if(!/[・]/.test(tag)&&!/^(名|副|イ形|ナ形|他|自|接|代|感|连|终|格|取|助数)/.test(tag))return tag;
    return tag.split('・').map(x=>dictionary[x]||x).join(' / ');
  };
  const progressFor=jp=>db.progress[jp]||{streak:0,lapses:0,dueAt:0,lastAt:0,seen:0,lastGrade:'again'};
  const isDue=w=>!!db.progress[w.jp] && db.progress[w.jp].seen>0 && db.progress[w.jp].dueAt<=Date.now();
  const isWeak=w=>(db.progress[w.jp]?.lapses||0)>0 && (db.progress[w.jp]?.streak||0)<3;
  function save(){if(!STORAGE.set(KEY,db))toast('当前浏览器未能保存记录，请检查存储设置');}
  let toastTimeout;
  function toast(message){const t=$('toast');t.textContent=message;t.classList.remove('hidden');clearTimeout(toastTimeout);toastTimeout=setTimeout(()=>t.classList.add('hidden'),3600);}
  /* Japanese speech: select ja-JP voice only, never fall back to a non-Japanese voice. */
  let japaneseVoices=[];
  const supportedSpeech=typeof window.speechSynthesis!=='undefined' && typeof window.SpeechSynthesisUtterance==='function';
  let currentUtterance=null;
  function getSpeechVoices(){
    japaneseVoices=supportedSpeech?window.speechSynthesis.getVoices().filter(v=>String(v.lang||'').toLowerCase().startsWith('ja')):[];
    const select=$('voiceSelect'),previous=select.value || db.settings?.voiceURI || '';
    select.innerHTML='';
    if(!japaneseVoices.length){const opt=document.createElement('option');opt.value='';opt.textContent='未检测到日语语音';select.appendChild(opt);$('voiceNotice').textContent='当前设备未提供可选的日语语音。请到系统语音设置添加日语音色；无法保证默认声音会读成标准日语。';return;}
    for(const v of japaneseVoices){const opt=document.createElement('option');opt.value=v.voiceURI;opt.textContent=v.name+(v.localService?' · 本机':'');select.appendChild(opt);}
    const preferred=japaneseVoices.find(v=>v.voiceURI===previous)||japaneseVoices.find(v=>/kyoko|otoya|nanami|siri|google|日本語/i.test(v.name))||japaneseVoices[0];
    select.value=preferred.voiceURI;
    $('voiceNotice').textContent='采用 ja-JP 日语语音；读音以词库中的假名为准。不同系统的音色和声调可能存在差异。';
  }
  function stopSpeech(){if(supportedSpeech){try{speechSynthesis.cancel()}catch{}}currentUtterance=null;}
  function speakJP(w){
    if(!supportedSpeech){toast('当前浏览器不支持系统朗读');return;}
    if(!japaneseVoices.length)getSpeechVoices();
    const selected=japaneseVoices.find(v=>v.voiceURI===$('voiceSelect').value);
    if(!selected){toast('没有可用的日语语音，请先安装日语系统音色');return;}
    const utterance=new SpeechSynthesisUtterance(w.kana||w.jp);
    utterance.lang='ja-JP';utterance.voice=selected;utterance.rate=.88;utterance.pitch=1;utterance.volume=1;
    currentUtterance=utterance;
    utterance.onerror=()=>toast('朗读失败，请检查设备的日语语音设置');
    try{speechSynthesis.cancel();speechSynthesis.speak(utterance)}catch{toast('朗读不可用，请检查浏览器权限')}
  }
  $('voiceSelect').onchange=()=>{db.settings.voiceURI=$('voiceSelect').value;save();};
  $('testVoice').onclick=()=>speakJP({jp:'こんにちは',kana:'こんにちは'});
  if(supportedSpeech){getSpeechVoices();speechSynthesis.addEventListener?.('voiceschanged',getSpeechVoices);}
  else {$('voiceSelect').disabled=true;$('voiceNotice').textContent='浏览器不支持系统语音朗读';}
  function updateHome(){let words=allWords();$('totalWords').textContent=words.length;$('reviewCount').textContent=words.filter(isDue).length;$('weakCount').textContent=words.filter(isWeak).length;}
  const views=['home','lessons','setup','summary','choose','done','library','stats','guide','study','test'];
  function view(name){stopSpeech();views.forEach(id=>$(id).classList.toggle('hidden',id!==name));document.body.classList.toggle('fake-landscape',false);window.scrollTo({top:0,left:0,behavior:'instant'});if(name==='home')updateHome();if(name==='lessons')renderLessons();if(name==='library')renderLibrary();if(name==='stats')renderStats();}
  document.querySelectorAll('[data-nav]').forEach(btn=>btn.addEventListener('click',()=>view(btn.dataset.nav)));
  $('openGuide').onclick=()=>view('guide');
  $('openLessons').onclick=()=>view('lessons');
  $('lessonToAll').onclick=()=>openSetup('all');
  $('openAll').onclick=()=>openSetup('all');
  $('openExtra').onclick=()=>openSetup('extra');
  $('openRandom').onclick=()=>{
    const words=randomize(allWords()).slice(0,Math.min(10,allWords().length));
    if(!words.length){toast('目前没有可抽查的词语');return;}
    session={queue:words.map(w=>w.jp),unique:words.map(w=>w.jp),cursor:0,visited:new Set(),kind:'random',lesson:null,revealed:false};
    activeLesson=null;
    view('choose');
  };
  $('openReview').onclick=()=>{
    const due=allWords().filter(isDue);
    if(due.length)openSetup('due');
    else if(allWords().some(isWeak))openSetup('weak');
    else toast('目前没有到期复习词。先学习几组新词吧。');
  };
  function renderLessons(){
    $('lessonList').innerHTML=BOOK.lessons.map(lesson=>{
      const pool=allWords().filter(w=>w.lessons?.includes(lesson.id));
      const left=remainingNewWords(pool,coverageScope('lesson',lesson.id)).length;
      return `<button class="lesson-card" data-lesson="${lesson.id}"><span class="lesson-num">${lesson.id.padStart(2,'0')}</span><span class="lesson-name"><strong>${esc(lesson.name)}</strong><small>${esc(lesson.cn)}${lesson.isPartial?' · 照片仅含部分词汇':''}</small></span><span class="lesson-count">${left}<small>待学 / ${pool.length}</small></span></button>`;
    }).join('');
    $('lessonList').querySelectorAll('[data-lesson]').forEach(btn=>btn.onclick=()=>openSetup('lesson',btn.dataset.lesson));
  }
  let setup={type:'all',lesson:null,pool:[]};
  function getPool(type,lesson){const words=allWords();if(type==='lesson')return words.filter(w=>w.lessons?.includes(lesson));if(type==='extra')return words.filter(w=>w.lessons?.includes('extra'));if(type==='due')return words.filter(isDue).sort((a,b)=>progressFor(a.jp).dueAt-progressFor(b.jp).dueAt);if(type==='weak')return words.filter(isWeak);return words;}
  function openSetup(type,lesson=null,selected=null){
    const fullPool=selected||getPool(type,lesson);
    if(!fullPool.length){toast('这个分类目前没有可学词语');return;}
    const scope=coverageScope(type,lesson);
    const remaining=remainingNewWords(fullPool,scope);
    // An exhausted course starts a fresh pass only when the user explicitly starts it.
    const newCycle=!!scope&&remaining.length===0;
    const pool=scope?(newCycle?fullPool:remaining):fullPool;
    setup={type,lesson,pool,fullSize:fullPool.length,scope,newCycle,qtyTouched:false};
    const titles={all:'总词汇库学习',extra:'课外词学习',lesson:COURSE.get(lesson)?.name||'按课学习',due:'到期复习',weak:'薄弱词复习',selected:'继续巩固'};
    const captions={all:'总词汇库包含课内、课外和自定义词；未学完前各轮不重复。',extra:'只学习课外词；与课内重合的单词只计一个，保留共同记忆进度。',lesson:`第 ${lesson} 课 · ${COURSE.get(lesson)?.cn||'教材词语'}`,due:'先回忆已经到复习时间的词。',weak:'这些是你过去标记过“不记得了”的词。',selected:'巩固刚才标记为遗忘的词。'};
    $('setupKicker').textContent=type==='lesson'?'TEXTBOOK / LESSON '+String(lesson).padStart(2,'0'):'KOTOBA / COLLECTION';
    $('setupTitle').textContent=titles[type]||titles.all;
    const status=scope?(newCycle?` · 全部 ${fullPool.length} 个词已看过；本次开始新一遍。`:` · 尚未学过 ${remaining.length} / ${fullPool.length} 个；本轮不重复旧词。`):'';
    $('setupDesc').textContent=(captions[type]||captions.all)+status;
    $('poolSize').textContent=pool.length;
    $('qty').value=Math.min(Math.max(1,db.settings.qty||10),pool.length);
    $('setupBack').onclick=()=>view(type==='lesson'?'lessons':'home');
    refreshQtyPills();view('setup');
  }
  function refreshQtyPills(){let val=Number($('qty').value);document.querySelectorAll('[data-qty]').forEach(b=>b.classList.toggle('selected',Number(b.dataset.qty)===val));$('allQty').classList.toggle('selected',val===setup.pool.length);}
  $('qty').addEventListener('input',()=>{setup.qtyTouched=true;refreshQtyPills();});
  document.querySelectorAll('[data-qty]').forEach(b=>b.onclick=()=>{setup.qtyTouched=true;$('qty').value=Math.min(+b.dataset.qty,setup.pool.length);refreshQtyPills();});
  $('allQty').onclick=()=>{setup.qtyTouched=true;$('qty').value=setup.pool.length;refreshQtyPills();};
  let session=null, quiz=null, lastWrong=[], batchQty=10;
  function beginSession(wordJPs,kind='all',lesson=null){
    if(!wordJPs.length){toast('暂无词语');return;}
    session={queue:[...wordJPs],unique:uniq(wordJPs),cursor:0,visited:new Set(),kind,lesson,revealed:false};
    activeLesson=kind==='lesson'?lesson:(kind==='extra'?'extra':null);
    view('study');renderStudy();
  }
  $('startSession').onclick=()=>{
    const v=Math.floor(Number($('qty').value));
    const qty=Math.min(setup.pool.length,Number.isFinite(v)&&v>0?v:10);
    batchQty=qty;
    if(setup.qtyTouched)db.settings.qty=qty;
    if(setup.newCycle&&setup.scope)db.coverage[setup.scope]=[];
    save();
    const chosen=setup.type==='due'?setup.pool.slice(0,qty):randomize(setup.pool).slice(0,qty);
    beginSession(chosen.map(w=>w.jp),setup.type,setup.lesson);
  };
  function renderStudy(){
    if(!session)return;
    if(session.cursor>=session.queue.length){finishSession();return;}
    const jp=session.queue[session.cursor],w=wordByJP(jp);if(!w){session.cursor++;renderStudy();return;}
    stopSpeech();session.revealed=false;session.visited.add(jp);
    markIntroduced(jp,session.kind,session.lesson);
    $('cardWord').textContent=w.jp;
    $('cardWord').classList.toggle('long-word',[...w.jp].length>=7);
    $('cardWord').classList.toggle('very-long-word',[...w.jp].length>=12);
    $('cardKana').textContent=w.kana;$('cardCn').textContent=w.cn;
    $('cardPos').textContent='词性 · '+posLabel(w.pos||'单词');
    $('cardLesson').textContent=w.lesson==='extra'?'个人词库':`第 ${w.lesson} 课 · P.${w.page}`;
    $('studyLabel').textContent=session.kind==='lesson'?`LESSON ${String(session.lesson).padStart(2,'0')}`:'WORD COLLECTION';
    $('cardNumber').textContent=String(session.cursor+1).padStart(3,'0');
    $('studyPage').textContent=`${String(session.cursor+1).padStart(2,'0')} / ${String(session.queue.length).padStart(2,'0')}`;
    $('studyProgressBar').style.width=`${((session.cursor+1)/session.queue.length)*100}%`;
    $('cardReveal').classList.add('hidden');$('cardInvite').classList.remove('hidden');
    $('prevCard').disabled=session.cursor===0;$('nextCard').disabled=false;
    $('nextCard').setAttribute('aria-label',session.cursor===session.queue.length-1?'完成学习':'下一词');
  }
  function reveal(){if(!session||session.revealed)return;session.revealed=true;$('cardReveal').classList.remove('hidden');$('cardInvite').classList.add('hidden');}
  $('flashcard').onclick=()=>reveal();
  $('flashcard').addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.repeat){e.preventDefault();reveal();}});
  $('speakStudy').onclick=()=>{const w=session&&wordByJP(session.queue[session.cursor]);if(w)speakJP(w);};
  let touchX=0,touchY=0,skipClickUntil=0;
  $('flashcard').addEventListener('touchstart',e=>{touchX=e.changedTouches[0].clientX;touchY=e.changedTouches[0].clientY;},{passive:true});
  $('flashcard').addEventListener('touchend',e=>{const dx=e.changedTouches[0].clientX-touchX,dy=e.changedTouches[0].clientY-touchY;if(Math.abs(dx)>55&&Math.abs(dx)>Math.abs(dy)*1.2){skipClickUntil=Date.now()+450;if(dx<0)goNext();else goPrev();}},{passive:true});
  $('flashcard').addEventListener('click',e=>{if(Date.now()<skipClickUntil)e.stopImmediatePropagation();},{capture:true});
  function goNext(){if(!session)return;if(session.cursor>=session.queue.length-1){finishSession();return;}session.cursor++;renderStudy();}
  function goPrev(){if(!session||session.cursor<=0)return;session.cursor--;renderStudy();}
  $('nextCard').onclick=goNext;$('prevCard').onclick=goPrev;
  document.addEventListener('keydown',e=>{if(!$('study').classList.contains('hidden')&&['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();e.key==='ArrowRight'?goNext():goPrev();}});
  function grade(jp,kind){
    const p=normalizeProgress(progressFor(jp));p.seen++;p.lastAt=Date.now();p.lastGrade=kind;
    if(kind==='again'){p.lapses++;p.streak=0;p.dueAt=Date.now()+10*MINUTE;}
    else {p.streak++;const days=[1,3,7,14,30,60,90][Math.min(p.streak-1,6)];p.dueAt=Date.now()+days*DAY;}
    db.progress[jp]=p;save();
  }
  function finishSession(){
    if(!session)return;
    $('summaryCount').innerHTML=`${session.unique.length}<small>词</small>`;
    $('summaryRemembered').textContent=session.visited.size;
    $('summaryForgot').textContent=session.unique.length;
    $('summaryReappear').textContent='—';
    $('summaryText').textContent='学习只负责熟悉词汇。现在开始考核，再决定哪些单词需要高频复习。';
    view('summary');
  }
  $('exitStudy').onclick=()=>finishSession();
  $('goTest').onclick=()=>{if(session)view('choose');};
  $('repeatWeak').onclick=()=>{if(session)beginSession([...session.unique],session.kind,session.lesson);};
  $('landscapeBtn').onclick=()=>{
    if(document.body.classList.contains('fake-landscape')){document.body.classList.remove('fake-landscape');return;}
    if(window.matchMedia('(orientation:landscape)').matches){toast('当前已经是横屏，正在使用宽屏布局');return;}
    document.body.classList.add('fake-landscape');
  };
  /* Written recall with explicit post-answer memory judgement. */
  document.querySelectorAll('[data-mode]').forEach(btn=>btn.onclick=()=>startTest(btn.dataset.mode));
  function startTest(mode){
    if(!session)return;
    quiz={mode,words:randomize([...session.unique]),index:0,results:[],answered:false,ok:false,forced:false,forgotSet:new Set(),repeats:{},sourceSize:session.unique.length};
    view('test');renderTest();
  }
  function renderTest(){
    stopSpeech();
    const w=wordByJP(quiz.words[quiz.index]);if(!w)return finishTest();
    quiz.answered=false;quiz.ok=false;quiz.forced=false;
    $('testModeLabel').textContent=quiz.mode==='cn-jp'?'中文 → 日语':'日语 → 中文';
    $('testCount').textContent=`${String(quiz.index+1).padStart(2,'0')} / ${String(quiz.words.length).padStart(2,'0')}`;
    $('testProgressBar').style.width=`${(quiz.index+1)/quiz.words.length*100}%`;
    $('questionWord').textContent=quiz.mode==='cn-jp'?w.cn:w.jp;
    $('questionWord').classList.toggle('long-question',[...$('questionWord').textContent].length>=10);
    $('testPrompt').textContent=quiz.mode==='cn-jp'?'写出日语词语 / 假名':'写出中文含义';
    $('answer').value='';$('answer').disabled=false;$('answer').classList.remove('hidden');
    $('answer').placeholder=quiz.mode==='cn-jp'?'输入日语或假名':'输入中文';
    $('testFeedback').classList.add('hidden');$('answerActions').classList.remove('hidden');
    $('testGradeRow').classList.add('hidden');$('overrideBtn').classList.add('hidden');$('testMemoryHint').classList.add('hidden');
    $('testRemember').disabled=false;
    $('speakTest').classList.toggle('hidden',quiz.mode==='cn-jp');
  }
  function isCorrect(w,answer){
    const value=norm(answer);if(!value)return false;
    if(quiz.mode==='cn-jp')return value===norm(w.jp)||value===norm(w.kana);
    const cn=w.cn.split(/[；;，,、/]/).map(s=>norm(s.replace(/（.*?）/g,''))).filter(Boolean);
    return cn.some(item=>value===item);
  }
  function revealTestAnswer(forced=false){
    if(!quiz||quiz.answered)return;
    const w=wordByJP(quiz.words[quiz.index]);if(!w)return;
    const a=$('answer').value.trim();if(!forced&&!a){toast('请输入答案，或选择“想不起来”');return;}
    quiz.answered=true;quiz.forced=forced;quiz.ok=!forced&&isCorrect(w,a);
    $('answer').disabled=true;$('answer').classList.add('hidden');$('answerActions').classList.add('hidden');
    const fb=$('testFeedback');fb.classList.remove('hidden');
    fb.innerHTML=`<strong class="${quiz.ok?'correct':'wrong'}">${quiz.ok?'✓ 答案正确':forced?'已经显示答案':'答案需要核对'}</strong><div>${esc(w.jp)} · ${esc(w.kana)}</div><div>${esc(w.cn)}</div>`;
    $('testGradeRow').classList.remove('hidden');$('testMemoryHint').classList.remove('hidden');
    $('testRemember').disabled=!quiz.ok;
    $('testMemoryHint').textContent=quiz.ok?'现在判断自己是否真正记得。':'若答案正确但未识别，可手动修正；否则选择“不记得了”。';
    $('overrideBtn').classList.toggle('hidden',quiz.ok||forced);
    $('speakTest').classList.remove('hidden');
  }
  $('answerBtn').onclick=()=>revealTestAnswer(false);
  $('skipAnswer').onclick=()=>revealTestAnswer(true);
  $('answer').onkeydown=e=>{if(e.key==='Enter'&&!e.isComposing){e.preventDefault();revealTestAnswer(false);}};
  $('overrideBtn').onclick=()=>{
    if(!quiz?.answered||quiz.forced)return;
    quiz.ok=true;$('testRemember').disabled=false;
    const fb=$('testFeedback');fb.querySelector('strong').textContent='✓ 已手动判定答案正确';fb.querySelector('strong').className='correct';
    $('overrideBtn').classList.add('hidden');$('testMemoryHint').textContent='请根据实际记忆情况评价。';
  };
  $('speakTest').onclick=()=>{const w=quiz&&wordByJP(quiz.words[quiz.index]);if(w)speakJP(w);};
  function commitMemory(remembered){
    if(!quiz||!quiz.answered)return;
    if(remembered&&!quiz.ok){toast('请先核对或修正答案');return;}
    const jp=quiz.words[quiz.index];
    const repeat=quiz.index>=quiz.sourceSize || quiz.forgotSet.has(jp);
    quiz.results.push({jp,ok:quiz.ok,remembered,repeat});
    if(!remembered){
      quiz.forgotSet.add(jp);grade(jp,'again');
      const count=quiz.repeats[jp]||0;
      if(count<2){const insert=Math.min(quiz.index+4,quiz.words.length);quiz.words.splice(insert,0,jp);quiz.repeats[jp]=count+1;}
    }else if(!quiz.forgotSet.has(jp)){grade(jp,'good');}
    // Recalling a word again within this test does not erase its short-term review obligation.
    quiz.index++;
    if(quiz.index>=quiz.words.length)finishTest();else renderTest();
  }
  $('testRemember').onclick=()=>commitMemory(true);
  $('testForgot').onclick=()=>commitMemory(false);
  $('exitTest').onclick=()=>{stopSpeech();view('choose')};
  function pendingNextBatch(){
    if(!session||!['lesson','all','extra'].includes(session.kind))return null;
    const pool=getPool(session.kind,session.lesson);
    return {remaining:remainingNewWords(pool,coverageScope(session.kind,session.lesson)),kind:session.kind,lesson:session.lesson};
  }
  function refreshContinueSession(){
    const btn=$('continueSession'),status=$('continueStatus'),next=pendingNextBatch();
    btn.classList.toggle('hidden',!next);
    status.classList.toggle('hidden',!next);
    if(!next)return;
    const label=next.kind==='lesson'?`第 ${next.lesson} 课`:(next.kind==='extra'?'课外词库':'总词汇库');
    if(!next.remaining.length){
      btn.disabled=true;
      btn.textContent='新词已全部学完';
      status.textContent=`${label}的新词已全部学习过。可以返回词库重新开始，或复习错词。`;
      return;
    }
    const count=Math.min(batchQty,next.remaining.length);
    btn.disabled=false;
    btn.innerHTML=`继续学习 ${count} 个新词 <span>→</span>`;
    status.textContent=`${label} · 还剩 ${next.remaining.length} 个未学词，下一组不会重复已学词。`;
  }
  $('continueSession').onclick=()=>{
    const next=pendingNextBatch();
    if(!next||!next.remaining.length){toast('当前没有剩余未学词');return;}
    const count=Math.min(Math.max(1,batchQty),next.remaining.length);
    const chosen=randomize(next.remaining).slice(0,count);
    beginSession(chosen.map(w=>w.jp),next.kind,next.lesson);
  };
  function finishTest(){
    if(!quiz)return;
    const uniqueFirst=new Map();
    for(const x of quiz.results)if(!uniqueFirst.has(x.jp))uniqueFirst.set(x.jp,x);
    const original=[...uniqueFirst.values()];
    const right=original.filter(r=>r.ok).length,total=original.length;
    lastWrong=uniq([...quiz.forgotSet,...original.filter(x=>!x.ok).map(x=>x.jp)]);
    db.logs.push({date:Date.now(),mode:quiz.mode,total,right,lesson:session?.lesson||null,forgot:quiz.forgotSet.size,repeat:quiz.results.length-total});
    db.logs=db.logs.slice(-500);save();
    $('score').textContent=`${total?Math.round(100*right/total):0}%`;
    $('scoreDetails').textContent=`原始题 ${total} · 答对 ${right} · 标记不记得 ${quiz.forgotSet.size} · 额外重现 ${Math.max(0,quiz.results.length-total)}`;
    $('doneReview').disabled=!lastWrong.length;
    refreshContinueSession();
    view('done');
  }
  $('swapMode').onclick=()=>startTest(quiz?.mode==='cn-jp'?'jp-cn':'cn-jp');
  $('doneReview').onclick=()=>{if(lastWrong.length)beginSession([...lastWrong],'weak');else toast('本轮没有薄弱词');};
  /* Word library + backups */
  $('wordSearch').oninput=renderLibrary;
  $('libLesson').onchange=renderLibrary;
  function renderLibrary(){
    const term=norm($('wordSearch').value),lesson=$('libLesson').value;
    const words=allWords().filter(w=>(lesson==='all'||(lesson==='textbook'?w.lessons?.some(l=>l!=='extra'):w.lessons?.includes(lesson)))&&(!term||norm(w.jp).includes(term)||norm(w.kana).includes(term)||norm(w.cn).includes(term)||Object.values(w.lessonVariants||{}).some(x=>norm(x.cn).includes(term))));
    const displayWord=w=>(lesson==='all'||lesson==='textbook')?w:{...w,...(w.lessonVariants?.[lesson]||{})};
    $('libCount').textContent=`显示 ${words.length} / ${allWords().length} 条`;
    $('wordList').innerHTML=words.length?words.map(original=>{const w=displayWord(original);return `<div class="word-line"><div class="word-line-main"><strong>${esc(w.jp)}</strong><span class="line-kana">${esc(w.kana)}</span><span class="line-cn">${esc(w.cn)}</span></div>${w.source==='custom'?`<button class="delete-word" data-delete="${encodeURIComponent(w.jp)}">删除</button>`:`<span class="line-source">${lesson==='all'&&original.lessons.length>1?original.lessons.map(l=>l==='extra'?'课外词':'第'+l+'课').join(' / '):w.lesson==='extra'?'课外词':`第${w.lesson}课 · ${w.page}页`}</span>`}</div>`}).join(''):'<div class="empty-state">没有符合条件的单词。</div>';
    $('wordList').querySelectorAll('[data-delete]').forEach(b=>b.onclick=()=>{
      const jp=decodeURIComponent(b.dataset.delete);if(!confirm(`删除自定义单词“${jp}”？`))return;
      db.custom=db.custom.filter(w=>w.jp!==jp);delete db.progress[jp];save();renderLibrary();updateHome();
    });
  }
  $('importBtn').onclick=()=>{
    const lines=$('importText').value.split(/\r?\n/).map(s=>s.trim()).filter(Boolean);
    let added=0,skipped=0;const seen=new Set(allWords().map(w=>w.jp));
    for(const line of lines.slice(0,1000)){
      const parts=(line.includes('|')?line.split('|'):line.split('\t')).map(clean);
      if(parts.length<3||!parts[0]||!parts[2]||seen.has(parts[0])){skipped++;continue;}
      const [jp,kana,cn,pos]=parts;db.custom.push({jp,kana:kana||jp,cn,pos:pos||'单词',lesson:'extra',section:'自行添加',source:'custom'});seen.add(jp);added++;
    }
    save();$('importStatus').textContent=`成功添加 ${added} 条，跳过 ${skipped} 条。`;$('importText').value='';renderLibrary();updateHome();
  };
  $('exportBtn').onclick=()=>{
    const data=JSON.stringify({...db,exportedAt:new Date().toISOString()},null,2);
    const a=document.createElement('a'),url=URL.createObjectURL(new Blob([data],{type:'application/json'}));
    a.href=url;a.download=`kotoba-backup-${new Date().toISOString().slice(0,10)}.json`;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
    toast('已导出备份，请保存到 iCloud 或电脑');
  };
  $('restoreFile').onchange=async e=>{
    const file=e.target.files[0];if(!file)return;
    try{
      if(file.size>3*1024*1024)throw Error('备份文件超过 3MB');
      const data=JSON.parse(await file.text());
      if(!data||![3,4].includes(Number(data.schema)))throw Error('不是兼容的词库备份');
      if(Number(data.schema)===3&&Array.isArray(data.words)){
        const known=new Set(allWords().map(w=>w.jp));
        for(const w of data.words.slice(0,5000))if(clean(w?.jp)&&clean(w?.cn)&&!known.has(clean(w.jp))){db.custom.push({jp:clean(w.jp),kana:clean(w.kana)||clean(w.jp),cn:clean(w.cn),pos:clean(w.pos)||'单词',lesson:'extra',section:'旧备份',source:'custom'});known.add(clean(w.jp));}
        let map=new Map(data.words.map(w=>[String(w.id),w.jp]));
        for(const [id,m] of Object.entries(data.mistakes||{}))if(m?.cnjp||m?.jpcn){const jp=map.get(String(id));if(jp&&!db.progress[jp])db.progress[jp]={streak:0,lapses:1,dueAt:Date.now()-1,lastAt:Date.now(),seen:1,lastGrade:'again'};}
      } else {
        const known=new Set(allWords().map(w=>w.jp));
        for(const w of (Array.isArray(data.custom)?data.custom:[]).slice(0,5000))if(clean(w?.jp)&&clean(w?.cn)&&!known.has(clean(w.jp))){db.custom.push({jp:clean(w.jp),kana:clean(w.kana)||clean(w.jp),cn:clean(w.cn),pos:clean(w.pos)||'单词',lesson:'extra',section:'备份导入',source:'custom'});known.add(clean(w.jp));}
        for(const [jp,p] of Object.entries(data.progress||{}))if(known.has(jp)&&!db.progress[jp])db.progress[jp]=normalizeProgress(p);
        const oldCoverage=data.coverage?normalizeCoverage(data.coverage):coverageFromProgress(allWords(),data.progress||{});
        for(const [scope,jps] of Object.entries(oldCoverage)){
          db.coverage[scope]=uniq([...(db.coverage[scope]||[]),...jps.filter(jp=>known.has(jp))]);
        }
      }
      if(Array.isArray(data.logs))db.logs=[...db.logs,...data.logs].slice(-500);
      save();renderLibrary();updateHome();toast('备份合并完成，已有学习记录已保留');
    }catch(err){toast('导入失败：'+err.message)}finally{e.target.value=''}
  };
  function renderStats(){
    const words=allWords();
    $('attemptsCount').textContent=db.logs.reduce((a,x)=>a+(Number(x.total)||0),0);
    $('learnedCount').textContent=words.filter(w=>progressFor(w.jp).seen>0).length;
    $('logsList').innerHTML=db.logs.length?[...db.logs].reverse().slice(0,35).map(x=>`<div class="log-row"><span>${esc(typeof x.date==='number'?dateText(x.date):x.date)}<small>${x.mode==='cn-jp'?'中文 → 日语':'日语 → 中文'}${x.lesson?' · 第'+esc(x.lesson)+'课':''}</small></span><strong>${Number(x.right)||0} / ${Number(x.total)||0}</strong></div>`).join(''):'<div class="empty-state">暂时还没有默写记录。</div>';
  }
  if('serviceWorker' in navigator&&location.protocol==='https:'){
    window.addEventListener('load',()=>navigator.serviceWorker.register('./sw.js').catch(()=>{}));
  }
  updateHome();
})();
