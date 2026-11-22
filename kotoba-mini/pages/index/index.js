'use strict';
const C=require('../../utils/core.js');
const KEY='kotoba_mini_v1';
function notify(message){ wx.showToast({title:String(message),icon:'none',duration:2200}); }
function unique(arr){return Array.from(new Set(arr));}
Page({
  data:{
    screen:'home',total:0,due:0,weak:0,volumeGroups:[],
    setupTitle:'',setupNotice:'',available:0,qty:10,
    current:{jp:'',kana:'',cn:'',pos:''},cardRevealed:false,
    studyPosition:'',progressPercent:0,summaryCount:0,
    quizDirection:'',quizPrompt:'',quizPosition:'',answerInput:'',
    answered:false,answerOK:false,answerForced:false,feedbackTitle:'',
    feedbackJP:'',feedbackKana:'',feedbackCN:'',
    testScore:'',testDetails:'',continueLabel:'继续学习',canContinue:false,continueStatus:'',
    filter:'all',search:'',libraryRows:[],libraryCount:0,
    logRows:[],learnedCount:0,attemptsCount:0,customInput:''
  },
  onLoad(){
    let stored=null;
    try{stored=wx.getStorageSync(KEY);}catch(e){}
    this.db=C.safeState(stored);
    this.library=C.buildLibrary(this.db.custom);
    this.session=null;this.quiz=null;this.lastWrong=[];
    this.refreshHome();
  },
  onShareAppMessage(){
    return {title:'ことば · 一天一点，慢慢记住日语单词',path:'/pages/index/index'};
  },
  save(){
    try{wx.setStorageSync(KEY,this.db);}
    catch(e){notify('学习记录未能保存，请检查微信存储空间');}
  },
  refreshHome(){
    const now=Date.now();
    const due=this.library.filter(w=>this.db.progress[w.jp]&&this.db.progress[w.jp].seen>0&&this.db.progress[w.jp].dueAt<=now).length;
    const weak=C.getPool(this.library,this.db,'weak',null,now).length;
    this.setData({screen:'home',total:this.library.length,due,weak});
  },
  showLessons(){
    const volumeGroups=[3,2].map(volume=>({
      volume,label:volume===3?'第三册':'第二册',
      lessons:C.lessons.filter(l=>l.volume===volume).map(l=>{
        const pool=C.getPool(this.library,this.db,'lesson',l.id);
        return {id:l.id,name:l.name,cn:l.cn,isPartial:l.isPartial,total:pool.length,left:C.remaining(pool,this.db,'lesson',l.id).length};
      })
    }));
    this.setData({screen:'lessons',volumeGroups});
  },
  goBack(){
    const screen=this.data.screen;
    if(screen==='setup'){this.setupKind==='lesson'?this.showLessons():this.refreshHome();return;}
    if(screen==='quiz'){this.setData({screen:'choice'});return;}
    if(screen==='study'){this.finishStudy();return;}
    this.refreshHome();
  },
  openLesson(e){this.prepare('lesson',String(e.currentTarget.dataset.id));},
  openKind(e){this.prepare(String(e.currentTarget.dataset.kind||'all'),null);},
  prepare(kind,lesson){
    if(kind==='due'&&C.getPool(this.library,this.db,'due').length===0){
      if(C.getPool(this.library,this.db,'weak').length)kind='weak';
      else{notify('当前没有到期复习词，先学习一些新词');return;}
    }
    const pool=C.getPool(this.library,this.db,kind,lesson);
    if(!pool.length){notify('这个分类暂无单词');return;}
    const remaining=C.remaining(pool,this.db,kind,lesson);
    const scope=C.scopeFor(kind,lesson);
    this.setupKind=kind;this.setupLesson=lesson;
    this.setupRestart=Boolean(scope&&remaining.length===0);
    const available=this.setupRestart?pool.length:remaining.length;
    const names={all:'总词汇库',extra:'课外词库',due:'到期复习',weak:'薄弱词复习'};
    const title=kind==='lesson'?C.lessonName(lesson):names[kind]||'开始学习';
    const notice=scope?(this.setupRestart?'本分类全部词语都已学过；本次开始新一轮。':'还剩 '+remaining.length+' 个未学词。学完并检测后可直接继续下一批，本轮不重复。'):'这轮将优先复习已经学过的单词。';
    this.setData({screen:'setup',setupTitle:title,setupNotice:notice,available,
      qty:Math.min(available,Math.max(1,Number(this.db.settings.qty)||10))});
  },
  chooseQty(e){
    let n=Number(e.currentTarget.dataset.qty);
    if(n===0)n=this.data.available;
    this.setData({qty:Math.max(1,Math.min(this.data.available,n))});
  },
  onQtyInput(e){const n=Number(e.detail.value);this.setData({qty:n});},
  startStudy(){
    const kind=this.setupKind,lesson=this.setupLesson;
    const pool=C.getPool(this.library,this.db,kind,lesson);
    const qty=Math.max(1,Math.min(this.data.available,Math.floor(Number(this.data.qty)||10)));
    const chosen=C.selectBatch(pool,this.db,kind,lesson,qty,null,this.setupRestart);
    if(!chosen.length){notify('暂无未学词汇');return;}
    this.db.settings.qty=qty;this.save();
    this.beginSession(chosen.map(x=>x.jp),kind,lesson,qty);
  },
  beginSession(jps,kind,lesson,batchQty){
    this.session={queue:jps.slice(),unique:unique(jps),index:0,
      visited:new Set(),kind,lesson,batchQty:batchQty||jps.length};
    this.quiz=null;
    this.renderStudy();
  },
  activeWord(jp){
    const w=this.library.find(x=>x.jp===jp);
    return w?C.forLesson(w,this.session&&this.session.kind==='lesson'?this.session.lesson:this.session&&this.session.kind==='extra'?'extra':null):null;
  },
  renderStudy(){
    const s=this.session;if(!s)return;
    if(s.index>=s.queue.length){this.finishStudy();return;}
    const jp=s.queue[s.index],w=this.activeWord(jp);
    if(!w){s.index++;this.renderStudy();return;}
    s.visited.add(jp);C.markIntroduced(this.db,jp,s.kind,s.lesson);this.save();
    this.setData({screen:'study',cardRevealed:false,
      current:{jp:w.jp,kana:w.kana,cn:w.cn,pos:C.posLabel(w.pos)},
      studyPosition:(s.index+1)+' / '+s.queue.length,
      progressPercent:Math.round((s.index+1)/s.queue.length*100)});
  },
  revealCard(){if(!this.ignoreNextTap)this.setData({cardRevealed:true});},
  touchStart(e){
    const t=e.changedTouches&&e.changedTouches[0];
    if(t){this.touchOrigin={x:t.pageX,y:t.pageY};this.ignoreNextTap=false;}
  },
  touchEnd(e){
    const t=e.changedTouches&&e.changedTouches[0],p=this.touchOrigin;
    if(!t||!p)return;
    const dx=t.pageX-p.x,dy=t.pageY-p.y;
    if(Math.abs(dx)>55&&Math.abs(dx)>Math.abs(dy)*1.2){
      this.ignoreNextTap=true;
      if(dx<0)this.nextCard();else this.prevCard();
    }
  },
  nextCard(){if(!this.session)return;if(this.session.index+1>=this.session.queue.length)this.finishStudy();else{this.session.index++;this.renderStudy();}},
  prevCard(){if(this.session&&this.session.index>0){this.session.index--;this.renderStudy();}},
  finishStudy(){
    if(!this.session){this.refreshHome();return;}
    this.setData({screen:'summary',summaryCount:this.session.unique.length});
  },
  repeatStudy(){
    if(this.session)this.beginSession(this.session.unique,this.session.kind,this.session.lesson,this.session.batchQty);
  },
  toChoice(){if(this.session)this.setData({screen:'choice'});},
  startQuiz(e){this.runQuiz(e.currentTarget.dataset.mode);},
  runQuiz(mode){
    if(!this.session)return;
    this.quiz={mode,words:C.shuffled(this.session.unique),index:0,
      answered:false,ok:false,forced:false,results:[],forgotSet:new Set(),repeats:{},sourceSize:this.session.unique.length};
    this.renderQuiz();
  },
  renderQuiz(){
    const q=this.quiz;if(!q)return;
    if(q.index>=q.words.length){this.finishQuiz();return;}
    const word=this.activeWord(q.words[q.index]);if(!word){q.index++;this.renderQuiz();return;}
    q.answered=false;q.ok=false;q.forced=false;
    this.setData({screen:'quiz',quizDirection:q.mode==='cn-jp'?'中文 → 日语':'日语 → 中文',
      quizPrompt:q.mode==='cn-jp'?word.cn:word.jp,
      quizPosition:(q.index+1)+' / '+q.words.length,answerInput:'',
      answered:false,answerOK:false,answerForced:false,feedbackTitle:'',feedbackJP:'',feedbackKana:'',feedbackCN:''});
  },
  onAnswerInput(e){this.setData({answerInput:e.detail.value});},
  checkAnswer(){this.revealQuiz(false);},
  skipAnswer(){this.revealQuiz(true);},
  revealQuiz(forced){
    const q=this.quiz;if(!q||q.answered)return;
    const answer=String(this.data.answerInput||'').trim();
    if(!forced&&!answer){notify('请输入答案，或选择想不起来');return;}
    const w=this.activeWord(q.words[q.index]);
    q.answered=true;q.forced=forced;q.ok=!forced&&C.answerCorrect(w,answer,q.mode);
    this.setData({answered:true,answerOK:q.ok,answerForced:forced,
      feedbackTitle:q.ok?'✓ 初步判定正确':forced?'已显示答案':'请核对答案',
      feedbackJP:w.jp,feedbackKana:w.kana,feedbackCN:w.cn});
  },
  overrideAnswer(){
    const q=this.quiz;if(!q||!q.answered||q.forced)return;
    q.ok=true;this.setData({answerOK:true,feedbackTitle:'✓ 已手动判定正确'});
  },
  markRemember(){this.commitGrade(true);},
  markForgot(){this.commitGrade(false);},
  commitGrade(remembered){
    const q=this.quiz;if(!q||!q.answered)return;
    if(remembered&&!q.ok){notify('请先核对答案并手动修正，或选择不记得');return;}
    const jp=q.words[q.index],repeat=q.index>=q.sourceSize||q.forgotSet.has(jp);
    q.results.push({jp,ok:q.ok,remembered,repeat});
    if(!remembered){
      q.forgotSet.add(jp);C.grade(this.db,jp,false);
      const count=q.repeats[jp]||0;
      if(count<2){const target=Math.min(q.index+4,q.words.length);q.words.splice(target,0,jp);q.repeats[jp]=count+1;}
    } else if(!q.forgotSet.has(jp)){C.grade(this.db,jp,true);}
    this.save();q.index++;this.renderQuiz();
  },
  finishQuiz(){
    const q=this.quiz;
    const seen=new Map();
    q.results.forEach(r=>{if(!seen.has(r.jp))seen.set(r.jp,r);});
    const initial=Array.from(seen.values()),correct=initial.filter(r=>r.ok).length;
    this.lastWrong=unique(Array.from(q.forgotSet).concat(initial.filter(r=>!r.ok).map(r=>r.jp)));
    this.db.logs.push({date:Date.now(),mode:q.mode,total:initial.length,right:correct,
      lesson:this.session.lesson||null,forgot:q.forgotSet.size,repeat:q.results.length-initial.length});
    this.db.logs=this.db.logs.slice(-500);this.save();
    const s=this.session,pool=C.getPool(this.library,this.db,s.kind,s.lesson);
    const left=C.remaining(pool,this.db,s.kind,s.lesson);
    const canContinue=['lesson','all','extra'].includes(s.kind)&&left.length>0;
    const label=s.kind==='lesson'?C.lessonName(s.lesson):s.kind==='extra'?'课外词库':'总词汇库';
    this.setData({screen:'done',testScore:(initial.length?Math.round(correct/initial.length*100):0)+'%',
      testDetails:'原始题 '+initial.length+' · 初判正确 '+correct+' · 标记遗忘 '+q.forgotSet.size+
        ' · 额外重现 '+Math.max(0,q.results.length-initial.length),
      canContinue,continueLabel:canContinue?'继续学习 '+Math.min(s.batchQty,left.length)+' 个新词':'新词已全部学完',
      continueStatus:['lesson','all','extra'].includes(s.kind)?label+' · 剩余 '+left.length+' 个未学词':'本轮复习已完成'});
  },
  continueStudy(){
    const s=this.session;
    if(!s||!['lesson','all','extra'].includes(s.kind))return;
    const pool=C.getPool(this.library,this.db,s.kind,s.lesson),left=C.remaining(pool,this.db,s.kind,s.lesson);
    if(!left.length){notify('当前分类没有剩余未学词');return;}
    const count=Math.min(s.batchQty,left.length);
    const next=C.selectBatch(pool,this.db,s.kind,s.lesson,count,null,false);
    this.beginSession(next.map(w=>w.jp),s.kind,s.lesson,s.batchQty);
  },
  swapDirection(){if(this.quiz)this.runQuiz(this.quiz.mode==='cn-jp'?'jp-cn':'cn-jp');},
  reviewWrong(){
    if(!this.lastWrong.length){notify('本轮没有错词');return;}
    this.beginSession(this.lastWrong,'weak',null,this.lastWrong.length);
  },
  showLibrary(){
    this.setData({screen:'library',filter:'all',search:''});
    this.renderLibrary('','all');
  },
  setFilter(e){const filter=e.currentTarget.dataset.filter;this.setData({filter});this.renderLibrary(this.data.search,filter);},
  onSearch(e){const search=e.detail.value;this.setData({search});this.renderLibrary(search,this.data.filter);},
  renderLibrary(search,filter){
    const term=C.normalizeAnswer(search);
    const found=this.library.filter(w=>{
      const scoped=filter==='all'||(filter==='textbook'?w.lessons.some(l=>l!=='extra'):w.lessons.includes('extra'));
      if(!scoped)return false;
      if(!term)return true;
      return [w.jp,w.kana,w.cn].some(s=>C.normalizeAnswer(s).includes(term)) ||
        Object.values(w.variants).some(v=>C.normalizeAnswer(v.cn).includes(term));
    });
    const rows=found.slice(0,120).map(w=>({jp:w.jp,kana:w.kana,cn:w.cn,
      category:w.lessons.includes('extra')?'课外词':C.lessonName(w.lessons[0])}));
    this.setData({libraryCount:found.length,libraryRows:rows});
  },
  onCustomInput(e){this.setData({customInput:e.detail.value});},
  importCustom(){
    const lines=String(this.data.customInput||'').split(/\r?\n/).map(x=>x.trim()).filter(Boolean);
    if(!lines.length){notify('请按格式输入词语');return;}
    const present=new Set(this.library.map(w=>w.jp));let added=0;
    for(const line of lines.slice(0,1000)){
      const a=(line.includes('|')?line.split('|'):line.split('\t')).map(x=>x.trim().slice(0,180));
      if(a.length<3||!a[0]||!a[2]||present.has(a[0]))continue;
      this.db.custom.push({jp:a[0],kana:a[1]||a[0],cn:a[2],pos:a[3]||'单词',lesson:'extra',source:'custom'});
      present.add(a[0]);added++;
    }
    this.library=C.buildLibrary(this.db.custom);this.save();
    this.setData({customInput:''});this.renderLibrary(this.data.search,this.data.filter);
    notify('新增 '+added+' 条单词');
  },
  showStats(){
    const logs=this.db.logs||[];
    const logRows=logs.slice(-30).reverse().map(x=>({
      date:new Date(Number(x.date)||Date.now()).toLocaleDateString('zh-CN'),
      mode:x.mode==='cn-jp'?'中文 → 日语':'日语 → 中文',right:Number(x.right)||0,total:Number(x.total)||0
    }));
    const learned=this.library.filter(w=>this.db.progress[w.jp]&&this.db.progress[w.jp].seen>0).length;
    const attempts=logs.reduce((n,x)=>n+(Number(x.total)||0),0);
    this.setData({screen:'stats',logRows,learnedCount:learned,attemptsCount:attempts});
  },
  showHelp(){this.setData({screen:'help'});},
  exportBackup(){
    const output=JSON.stringify(Object.assign({},this.db,{exportedAt:new Date().toISOString()}));
    const fs=wx.getFileSystemManager();
    const name='kotoba-backup-'+new Date().toISOString().slice(0,10)+'.json';
    const path=wx.env.USER_DATA_PATH+'/'+name;
    fs.writeFile({filePath:path,data:output,encoding:'utf8',success:()=>{
      if(typeof wx.shareFileMessage==='function'){
        wx.shareFileMessage({filePath:path,fileName:name,fail:()=>notify('分享失败，请在支持的微信版本重试')});
      }else if(output.length<95000){
        wx.setClipboardData({data:output,success:()=>notify('已将备份复制到剪贴板')});
      }else notify('当前微信版本暂不支持文件分享，请勿清理小程序数据');
    },fail:()=>notify('备份文件写入失败')});
  },
  importBackup(){
    if(typeof wx.chooseMessageFile!=='function'){notify('当前微信版本暂不支持选择聊天文件');return;}
    wx.chooseMessageFile({count:1,type:'file',extension:['json'],success:(res)=>{
      const file=res.tempFiles&&res.tempFiles[0];
      if(!file||Number(file.size)>3*1024*1024){notify('请选择小于3MB的JSON备份');return;}
      wx.getFileSystemManager().readFile({filePath:file.path,encoding:'utf8',success:(result)=>{
        try{
          const parsed=JSON.parse(result.data);
          this.db=C.mergeBackup(this.db,parsed);
          this.library=C.buildLibrary(this.db.custom);this.save();this.refreshHome();
          notify('网页版学习备份已合并');
        }catch(e){notify('导入失败：'+String(e.message||'备份无效').slice(0,24));}
      },fail:()=>notify('无法读取选中的文件')});
    }});
  }
});
