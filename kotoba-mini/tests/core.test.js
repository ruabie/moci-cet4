const assert=require('node:assert/strict');
const test=require('node:test');
const C=require('../utils/core.js');
test('word snapshot: full curriculum plus chat vocabulary',()=>{
  assert.equal(C.SOURCE.entries.length,819);
  assert.equal(C.buildLibrary([]).length,752);
  assert.equal(C.lessons.length,10);
  assert.equal(C.volumeOf('5'),3);
  assert.equal(C.volumeOf('15'),2);
});
test('same spelling shares one progress key and retains lesson variants',()=>{
  const words=C.buildLibrary([]);
  const across=words.find(w=>w.lessons.length>1);
  assert.ok(across);
  for(const lesson of across.lessons)assert.ok(C.forLesson(across,lesson).cn);
});
test('no repeat across new-word batches and explicit restart only',()=>{
  const s=C.blankState(), w=C.buildLibrary([]).filter(w=>w.lessons.includes('4'));
  let a=C.selectBatch(w,s,'lesson','4',10,()=>0.5,false);
  assert.equal(a.length,10);
  a.forEach(x=>C.markIntroduced(s,x.jp,'lesson','4'));
  let b=C.selectBatch(w,s,'lesson','4',10,()=>0.5,false);
  assert.equal(b.length,10);
  assert.ok(b.every(x=>!a.some(y=>y.jp===x.jp)));
  for(const x of w)C.markIntroduced(s,x.jp,'lesson','4');
  assert.equal(C.selectBatch(w,s,'lesson','4',10,()=>0.5,false).length,0);
  assert.equal(C.selectBatch(w,s,'lesson','4',10,()=>0.5,true).length,10);
});
test('answer check supports kana and manual review for meaning alternatives',()=>{
  const w={jp:'異なる',kana:'ことなる',cn:'不同；不一样'};
  assert.equal(C.answerCorrect(w,'ことなる','cn-jp'),true);
  assert.equal(C.answerCorrect(w,'不一样','jp-cn'),true);
  assert.equal(C.answerCorrect(w,'完全不同','jp-cn'),false);
});
test('SRS: 10min lapse then 1d/3d good',()=>{
  const s=C.blankState(),t=100000000;
  assert.equal(C.grade(s,'異なる',false,t).dueAt,t+600000);
  assert.equal(C.grade(s,'異なる',true,t).dueAt,t+86400000);
  assert.equal(C.grade(s,'異なる',true,t).dueAt,t+3*86400000);
});
test('browser schema4 backup merges without deleting current progress',()=>{
  const s=C.blankState();s.progress.a={seen:3,dueAt:10};
  const b=C.blankState();b.custom=[{jp:'テスト',kana:'テスト',cn:'测试',pos:'名词'}];b.progress.b={seen:1,dueAt:20};
  const n=C.mergeBackup(s,b);
  assert.equal(n.progress.a.seen,3);assert.equal(n.progress.b.seen,1);
  assert.equal(n.custom[0].jp,'テスト');
});
