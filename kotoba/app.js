(() => {
  'use strict';
  const KEY = 'kotoba_pwa_v3';
  const LEGACY_KEYS = ['kotoba_v2_ins', 'kotoba_v1'];
  const $ = id => document.getElementById(id);
  const escapeHtml = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const seed = [
    ['さまざま','さまざま','各种各样','形容动词'],
    ['経験','けいけん','经验','名词'],
    ['迷惑','めいわく','麻烦；困扰','名词'],
    ['学ぶ','まなぶ','学习','动词'],
    ['学び','まなび','学习；学问','名词'],
    ['奢る','おごる','请客；奢侈','动词'],
    ['謝る','あやまる','道歉','动词'],
    ['許す','ゆるす','原谅；允许','动词'],
    ['甘い','あまい','甜的；天真的','形容词'],
    ['相手','あいて','对方；伙伴','名词'],
    ['川','かわ','河流','名词'],
    ['泳ぐ','およぐ','游泳','动词'],
    ['伺う','うかがう','拜访；请教；询问','动词'],
    ['平和','へいわ','和平','名词'],
    ['僕','ぼく','我（男性常用）','代词'],
    ['偉い','えらい','了不起的；地位高的','形容词'],
    ['彼女','かのじょ','她；女朋友','代词'],
    ['おぼつかない','おぼつかない','没把握的；不可靠的','形容词'],
    ['しっかり','しっかり','牢固地；好好地','副词'],
    ['ゆっくり','ゆっくり','慢慢地','副词'],
    ['さまざまな','さまざまな','各种各样的','连体表达'],
    ['詳しい','くわしい','详细的；熟悉的','形容词'],
    ['大津波','おおつなみ','大海啸','名词'],
    ['常に','つねに','经常；总是','副词'],
    ['素晴らしい','すばらしい','非常出色的；精彩的','形容词'],
    ['体','からだ','身体','名词'],
    ['輸入車','ゆにゅうしゃ','进口车','名词'],
    ['反省する','はんせいする','反省；检讨自己的行为','动词'],
    ['中秋節','ちゅうしゅうせつ','中秋节','名词']
  ];

  const seedWords = () => seed.map((a, i) => ({ id: i+1, jp:a[0], kana:a[1], cn:a[2], pos:a[3] }));
  const emptyDB = () => ({schema:3, words:seedWords(), mistakes:{}, logs:[]});
  let db;
  const isObject = v => v && typeof v === 'object' && !Array.isArray(v);
  const readLS = key => { try {return JSON.parse(localStorage.getItem(key))} catch {return null} };
  const safeWord = w => {
    if (!w || typeof w.jp !== 'string' || typeof w.cn !== 'string') return null;
    const jp = w.jp.trim().slice(0,100), cn = w.cn.trim().slice(0,220);
    if (!jp || !cn) return null;
    return {id: Number.isSafeInteger(Number(w.id)) && Number(w.id)>0 ? Number(w.id) : 0,
      jp, cn, kana: typeof w.kana === 'string' ? w.kana.trim().slice(0,100) || jp : jp,
      pos: typeof w.pos === 'string' ? w.pos.trim().slice(0,50) || '单词' : '单词'};
  };
  function normalizeDB(raw, withSeed = true) {
    const result = {schema:3, words:withSeed ? seedWords() : [], mistakes:{}, logs:[]};
    if(!raw || !Array.isArray(raw.words)) return result;
    const seen = new Map(result.words.map(w=>[w.jp, w.id]));
    let nextId = result.words.length ? Math.max(...result.words.map(w=>w.id))+1 : 1;
    const idMap = new Map();
    for(const item of raw.words.slice(0,5000)) {
      const w = safeWord(item);
      if(!w) continue;
      let id;
      if(seen.has(w.jp)) id = seen.get(w.jp);
      else {id=nextId++;result.words.push({...w,id});seen.set(w.jp,id)}
      if(w.id) idMap.set(w.id,id);
    }
    if(isObject(raw.mistakes)) {
      for(const [id, obj] of Object.entries(raw.mistakes)) {
        const newId=idMap.get(Number(id)) ?? Number(id);
        if(!result.words.some(w=>w.id===newId))continue;
        if(isObject(obj)) result.mistakes[newId]={cnjp:!!obj.cnjp,jpcn:!!obj.jpcn};
      }
    }
    if(Array.isArray(raw.wrong)) {
      for(const oldId of raw.wrong) {
        const newId=idMap.get(Number(oldId)) ?? Number(oldId);
        if(result.words.some(w=>w.id===newId))result.mistakes[newId]={cnjp:true,jpcn:true};
      }
    }
    if(Array.isArray(raw.logs)) {
      result.logs=raw.logs.slice(-500).filter(l=>l&&typeof l==='object').map(l=>({
        date:String(l.date??'' ).slice(0,50), mode:l.mode==='jp-cn'?'jp-cn':'cn-jp',
        total:Math.max(0,Number(l.total)||0), right:Math.max(0,Number(l.right)||0)
      }));
    }
    return result;
  }
  function initDB(){
    const current=readLS(KEY);
    if(current&&Array.isArray(current.words)) return normalizeDB(current,false);
    for(const key of LEGACY_KEYS){const raw=readLS(key);if(raw&&Array.isArray(raw.words))return normalizeDB(raw,true)}
    return emptyDB();
  }
  db=initDB();
  function save(){
    try{localStorage.setItem(KEY,JSON.stringify(db));return true}
    catch(err){alert('无法保存学习记录。请检查浏览器是否启用了无痕模式，或存储空间是否已满。');return false}
  }
  save();
  function wrongIds(){return db.words.filter(w=>{
    const m=db.mistakes[w.id];return m&&(m.cnjp||m.jpcn);
  }).map(w=>w.id)}
  const screens=['home','study','choose','test','done','library','stats'];
  let currentScreen='home';
  function show(id){
    currentScreen=id;
    for(const s of screens)$(s).classList.toggle('hidden',s!==id);
    window.scrollTo({top:0,behavior:'instant'});
    if(id==='home') refresh();
    if(id==='library') renderLib();
    if(id==='stats') renderStats();
  }
  function refresh(){
    $('total').textContent=db.words.length;
    $('wrongTotal').textContent=wrongIds().length;
    $('review').disabled=wrongIds().length===0;
  }
  let session=[], idx=0, mode='cn-jp', testIndex=0, results=[], answered=false, revealed=false;
  function shuffle(a){
    const out=a.slice();
    for(let i=out.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[out[i],out[j]]=[out[j],out[i]];}
    return out;
  }
  function makeSession(onlyWrong=false){
    const wrong=new Set(wrongIds());
    const pool=onlyWrong?db.words.filter(w=>wrong.has(w.id)):db.words;
    if(!pool.length){alert(onlyWrong?'目前没有错词':'词库为空，请先添加单词');return}
    const qty=Math.min(999,Math.max(1,Number.parseInt($('qty').value,10)||10));
    session=shuffle(pool).slice(0,qty);
    idx=0;
    show('study');renderCard();
  }
  function reveal(){revealed=true;$('cardMeaning').classList.remove('concealed');$('revealMeaning').textContent='释义已显示';$('revealMeaning').setAttribute('aria-pressed','true')}
  function renderCard(dir='next'){
    const w=session[idx];if(!w){show('home');return}
    revealed=false;
    $('cardIndex').textContent='KOTOBA / '+String(idx+1).padStart(2,'0');
    $('cardTag').textContent=w.pos||'VOCABULARY';
    $('cardWord').textContent=w.jp;
    $('cardReading').textContent=w.kana===w.jp?'':w.kana;
    $('cardMeaning').textContent=w.cn;
    $('cardMeaning').classList.add('concealed');
    $('revealMeaning').textContent='轻触显示释义';
    $('revealMeaning').setAttribute('aria-pressed','false');
    $('studyCount').textContent=`${idx+1} / ${session.length}`;
    $('pageCount').textContent=`${String(idx+1).padStart(2,'0')} — ${String(session.length).padStart(2,'0')}`;
    $('studyBar').style.width=`${(idx+1)/session.length*100}%`;
    $('prev').disabled=idx===0;
    $('next').disabled=idx===session.length-1;
    $('finishStudy').classList.toggle('hidden',idx!==session.length-1);
    const card=$('card');
    card.classList.remove('turn-next','turn-prev'); void card.offsetWidth;
    card.classList.add(dir==='next'?'turn-next':'turn-prev');
  }
  function page(d){const n=idx+d;if(n<0||n>=session.length)return;idx=n;renderCard(d>0?'next':'prev')}
  $('start').addEventListener('click',()=>makeSession());
  $('review').addEventListener('click',()=>makeSession(true));
  $('prev').addEventListener('click',()=>page(-1));
  $('next').addEventListener('click',()=>page(1));
  $('revealMeaning').addEventListener('click',e=>{e.stopPropagation();reveal()});
  $('card').addEventListener('click',e=>{if(e.target.closest('button'))return;if(!revealed)reveal()});
  $('finishStudy').addEventListener('click',()=>show('choose'));
  $('chooseBack').addEventListener('click',()=>show('study'));
  $('homeBtn').addEventListener('click',()=>show('home'));
  $('libraryBtn').addEventListener('click',()=>show('library'));
  $('statsBtn').addEventListener('click',()=>show('stats'));
  $('libBack').addEventListener('click',()=>show('home'));
  $('statsBack').addEventListener('click',()=>show('home'));
  document.querySelectorAll('[data-mode]').forEach(b=>b.addEventListener('click',()=>{
    mode=b.dataset.mode;setModeButtons();
  }));
  function setModeButtons(){document.querySelectorAll('[data-mode]').forEach(b=>b.classList.toggle('selected',b.dataset.mode===mode))}
  let startX=0,startY=0;
  $('card').addEventListener('touchstart',e=>{startX=e.changedTouches[0].clientX;startY=e.changedTouches[0].clientY},{passive:true});
  $('card').addEventListener('touchend',e=>{
    const dx=e.changedTouches[0].clientX-startX,dy=e.changedTouches[0].clientY-startY;
    if(Math.abs(dx)>48 && Math.abs(dx)>Math.abs(dy)*1.3)page(dx<0?1:-1);
  },{passive:true});
  document.addEventListener('keydown',e=>{
    if(currentScreen!=='study'||['INPUT','TEXTAREA','BUTTON'].includes(document.activeElement.tagName))return;
    if(e.key==='ArrowRight'){e.preventDefault();page(1)}
    if(e.key==='ArrowLeft'){e.preventDefault();page(-1)}
    if(e.key===' '){e.preventDefault();reveal()}
  });

  const normalizeText = s => String(s??'').trim().toLowerCase()
    .replace(/[\s　。、，,.!！?？・]/g,'').replace(/[（）()]/g,'');
  const hiragana = s => s.replace(/[ァ-ヶ]/g,c=>String.fromCharCode(c.charCodeAt(0)-0x60));
  function check(w,answer){
    const x=normalizeText(answer);if(!x)return false;
    if(mode==='cn-jp')return hiragana(x)===hiragana(normalizeText(w.jp))||hiragana(x)===hiragana(normalizeText(w.kana));
    const options=w.cn.split(/[；;、/]/).map(normalizeText).filter(Boolean);
    return options.some(v=>v===x||(v.includes(x)&&x.length>=2)||(x.includes(v)&&v.length>=2));
  }
  function renderTest(){
    const w=session[testIndex];answered=false;
    $('testCount').textContent=`Question ${testIndex+1} / ${session.length}`;
    $('promptLabel').textContent=mode==='cn-jp'?'根据中文，写出日语':'根据日语，写出中文';
    $('promptWord').textContent=mode==='cn-jp'?w.cn:w.jp;
    $('promptReading').textContent='';
    $('answer').value='';$('answer').disabled=false;
    $('feedback').classList.add('hidden');
    $('override').classList.add('hidden');
    $('submitAnswer').textContent='确认答案';
  }
  function startTest(){testIndex=0;results=[];show('test');renderTest()}
  $('startTest').addEventListener('click',startTest);
  $('testBack').addEventListener('click',()=>show('choose'));
  function commit(ok){
    const w=session[testIndex];results.push({id:w.id,ok});
    const m=db.mistakes[w.id]||{cnjp:false,jpcn:false};
    m[mode==='cn-jp'?'cnjp':'jpcn']=!ok;
    db.mistakes[w.id]=m;save();
  }
  function submit(){
    if(answered){testIndex++;if(testIndex>=session.length)finish();else renderTest();return}
    const answer=$('answer').value;if(!answer.trim()){$('answer').focus();return}
    const w=session[testIndex],ok=check(w,answer);
    commit(ok);answered=true;$('answer').disabled=true;
    $('feedback').classList.remove('hidden');
    $('feedback').innerHTML=`<strong class="${ok?'good':'bad'}">${ok?'✓ 回答正确':'✕ 需要复习'}</strong><div style="margin-top:8px">日语：${escapeHtml(w.jp)}（${escapeHtml(w.kana)}）<br>中文：${escapeHtml(w.cn)}</div>`;
    $('override').classList.toggle('hidden',ok);
    $('submitAnswer').textContent=testIndex===session.length-1?'查看学习结果':'下一题 →';
  }
  $('submitAnswer').addEventListener('click',submit);
  $('answer').addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.isComposing){e.preventDefault();submit()}});
  $('override').addEventListener('click',()=>{
    const r=results[results.length-1];if(!r)return;
    r.ok=true;const m=db.mistakes[r.id]||{cnjp:false,jpcn:false};
    m[mode==='cn-jp'?'cnjp':'jpcn']=false;db.mistakes[r.id]=m;save();
    const strong=$('feedback').querySelector('strong');
    strong.textContent='✓ 已手动判定正确';strong.className='good';
    $('override').classList.add('hidden');
  });
  function finish(){
    const right=results.filter(r=>r.ok).length;
    db.logs.push({date:new Date().toLocaleString('zh-CN'),mode,total:results.length,right});
    db.logs=db.logs.slice(-500);save();
    $('score').textContent=Math.round(right/results.length*100)+'%';
    $('scoreDetail').textContent=`${results.length} 个词语 · 正确 ${right} 个 · 错误 ${results.length-right} 个`;
    $('again').disabled=results.every(r=>r.ok);
    show('done');
  }
  $('again').addEventListener('click',()=>{
    const ids=new Set(results.filter(r=>!r.ok).map(r=>r.id));
    session=session.filter(w=>ids.has(w.id));
    if(!session.length){show('home');return}
    idx=0;show('study');renderCard();
  });
  $('otherMode').addEventListener('click',()=>{mode=mode==='cn-jp'?'jp-cn':'cn-jp';setModeButtons();startTest()});
  $('doneHome').addEventListener('click',()=>show('home'));

  function nextId(){return db.words.reduce((acc,w)=>Math.max(acc,w.id),0)+1}
  $('importBtn').addEventListener('click',()=>{
    const lines=$('importText').value.split(/\r?\n/).map(s=>s.trim()).filter(Boolean);
    let added=0,skipped=0, id=nextId();
    const known=new Set(db.words.map(w=>w.jp));
    for(const line of lines.slice(0,5000)){
      const parts=(line.includes('|')?line.split('|'):line.split('\t')).map(s=>s.trim());
      if(parts.length<3||!parts[0]||!parts[2]||known.has(parts[0])){skipped++;continue}
      const w=safeWord({id:id++,jp:parts[0],kana:parts[1],cn:parts[2],pos:parts[3]||'单词'});
      if(!w){skipped++;continue}db.words.push(w);known.add(w.jp);added++;
    }
    save();$('importMsg').textContent=`已加入 ${added} 个；跳过 ${skipped} 行。`;
    $('importText').value='';renderLib();refresh();
  });
  function renderLib(){
    const q=normalizeText($('wordSearch').value);
    const list=db.words.filter(w=>!q||[w.jp,w.kana,w.cn,w.pos].some(x=>normalizeText(x).includes(q)));
    $('wordList').innerHTML=list.length?list.map(w=>`<div class="word-row"><div class="word-meta"><strong>${escapeHtml(w.jp)}</strong><div class="kana">${escapeHtml(w.kana)}</div><div class="cn">${escapeHtml(w.cn)} · ${escapeHtml(w.pos)}</div></div><button class="mini-link" data-delete="${w.id}" aria-label="删除${escapeHtml(w.jp)}">删除</button></div>`).join(''):'<div class="empty">没有找到匹配的词语。</div>';
    $('wordList').querySelectorAll('[data-delete]').forEach(b=>b.addEventListener('click',()=>{
      const id=Number(b.dataset.delete);
      if(!confirm('确定删除这个词吗？'))return;
      db.words=db.words.filter(w=>w.id!==id);delete db.mistakes[id];save();renderLib();refresh();
    }));
  }
  $('wordSearch').addEventListener('input',renderLib);
  $('resetWrong').addEventListener('click',()=>{
    if(!confirm('确定清空全部错词标记吗？这不会删除词语和测试历史。'))return;
    db.mistakes={};save();refresh();alert('已清空错词标记');
  });
  function backup(){
    const data={...db,exportedAt:new Date().toISOString(),app:'kotoba'};
    const blob=new Blob([JSON.stringify(data,null,2)],{type:'application/json'});
    const url=URL.createObjectURL(blob),a=document.createElement('a');
    a.href=url;a.download=`kotoba-backup-${new Date().toISOString().slice(0,10)}.json`;
    document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),5000);
    $('backupStatus').textContent='备份文件已生成。请保存到 iPhone「文件」或电脑的可靠位置。';
  }
  $('backupBtn').addEventListener('click',backup);
  $('exportBtn').addEventListener('click',backup);
  $('restoreBtn').addEventListener('click',()=>$('restoreFile').click());
  $('restoreFile').addEventListener('change',async e=>{
    const file=e.target.files?.[0];if(!file)return;
    try{
      if(file.size>2_000_000)throw Error('文件超过 2MB，暂不支持');
      const raw=JSON.parse(await file.text());
      if(!raw||!Array.isArray(raw.words))throw Error('文件格式不是支持的词库备份');
      const incoming=normalizeDB(raw,false);
      if(!incoming.words.length)throw Error('备份里没有有效词条');
      const keep=db.words.length, existing=new Map(db.words.map(w=>[w.jp,w.id]));
      const mapped=new Map();let n=nextId();
      for(const w of incoming.words){
        let id=existing.get(w.jp);
        if(id===undefined){id=n++;db.words.push({...w,id});existing.set(w.jp,id)}
        mapped.set(w.id,id);
      }
      for(const [id,val] of Object.entries(incoming.mistakes)){
        const targetId=mapped.get(Number(id));if(targetId!==undefined)db.mistakes[targetId]={
          cnjp:!!val.cnjp||!!db.mistakes[targetId]?.cnjp,
          jpcn:!!val.jpcn||!!db.mistakes[targetId]?.jpcn
        };
      }
      db.logs=[...db.logs,...incoming.logs].slice(-500);
      save();renderLib();refresh();
      $('backupStatus').textContent=`导入完成：新增 ${db.words.length-keep} 个词，合并 ${incoming.words.length-(db.words.length-keep)} 个已有词。旧备份中的错词记录也已合并。`;
    }catch(err){$('backupStatus').textContent=`导入失败：${err.message}`}
    finally{e.target.value=''}
  });
  function renderStats(){
    const logs=[...db.logs].reverse();
    $('statsContent').innerHTML=`<div class="tiny">累计测试次数</div><div class="result-number" style="font-size:46px">${logs.length}</div><div class="subtitle" style="margin-bottom:10px">错词 ${wrongIds().length} 个 · 词库 ${db.words.length} 个</div>` +
      (logs.length?logs.slice(0,30).map(x=>`<div class="word-row"><div class="word-meta"><strong>${escapeHtml(x.date)}</strong><div class="cn">${x.mode==='cn-jp'?'中文 → 日语':'日语 → 中文'}</div></div><div style="font-family:Georgia,serif;font-size:20px">${x.right}/${x.total}</div></div>`).join(''):'<div class="empty">还没有默写记录。完成一轮测试后会显示在这里。</div>');
  }
  if('serviceWorker' in navigator && (location.protocol==='https:' || location.hostname==='localhost')) {
    window.addEventListener('load',()=>navigator.serviceWorker.register('./sw.js').catch(()=>{}));
  }
  refresh();
})();
