'use strict';
const fs=require('node:fs');
const assert=require('node:assert/strict');
const puppeteer=require('puppeteer-core');
const url='https://ruabie.github.io/moci-cet4/kotoba-ios/?visual-qa=v2';
const out='qa-artifacts/kotoba-ios-v2';
fs.mkdirSync(out,{recursive:true});
const visible=async(page,id)=>page.evaluate(id=>{const el=document.querySelector(id);return !!el&&!el.classList.contains('hidden')&&getComputedStyle(el).display!=='none'},id);
const rect=async(page,id)=>page.evaluate(id=>{const e=document.querySelector(id);const r=e.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height}},id);
const noOverflow=async(page,label)=>{
 const data=await page.evaluate(()=>({scroll:document.documentElement.scrollWidth,width:innerWidth}));
 assert.ok(data.scroll<=data.width+2,label+' overflow '+JSON.stringify(data));
};
async function run(){
 const browser=await puppeteer.launch({
  executablePath:process.env.CHROME_BIN||'/usr/bin/google-chrome',
  headless:true,args:['--no-sandbox','--disable-dev-shm-usage']
 });
 try{
  const page=await browser.newPage();
  await page.setViewport({width:390,height:844,isMobile:true,hasTouch:true,deviceScaleFactor:2});
  await page.emulateMediaFeatures([{name:'prefers-color-scheme',value:'light'},{name:'prefers-reduced-motion',value:'reduce'}]);
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(url,{waitUntil:'networkidle2',timeout:45000});
  await page.waitForFunction(()=>Number(document.getElementById('totalWords')?.textContent)>700,{timeout:15000});
  assert.ok(await visible(page,'#home'));
  assert.equal(await page.$$eval('.ios-smart-tile',e=>e.length),4);
  assert.ok(await page.$eval('.ios-inset-group',e=>getComputedStyle(e).borderRadius!=='0px'));
  assert.equal(await page.$eval('.ios-tabbar',e=>getComputedStyle(e).position),'fixed');
  const nav=await rect(page,'.ios-tabbar');
  assert.ok(nav.y>650&&nav.y+nav.h<=844,'Floating tab bar must fit iPhone viewport '+JSON.stringify(nav));
  await noOverflow(page,'Home');
  await page.screenshot({path:out+'/home-light.png',fullPage:true});
  await page.click('#openLessons');
  await page.waitForFunction(()=>!document.getElementById('lessons').classList.contains('hidden'));
  assert.ok(await page.$('[data-lesson="4"]'),'Lesson four missing');
  await noOverflow(page,'Lessons');
  await page.screenshot({path:out+'/lessons.png',fullPage:true});
  await page.click('[data-lesson="4"]');
  await page.waitForFunction(()=>!document.getElementById('setup').classList.contains('hidden'));
  await noOverflow(page,'Setup');
  await page.screenshot({path:out+'/setup.png',fullPage:true});
  await page.click('#startSession');
  await page.waitForFunction(()=>!document.getElementById('study').classList.contains('hidden'));
  assert.ok((await page.$eval('#cardWord',e=>e.textContent)).length>0);
  assert.equal(await visible(page,'#test'),false);
  await page.click('#flashcard');
  assert.equal(await page.$eval('#cardReveal',e=>e.classList.contains('hidden')),false);
  await noOverflow(page,'Study');
  await page.screenshot({path:out+'/study.png'});
  // Complete page flipping to exercise real study->summary->assessment transition.
  for(let i=0;i<30&&await visible(page,'#study');i++){
   await page.click('#nextCard');
  }
  assert.ok(await visible(page,'#summary'),'Finishing study should show summary');
  await page.click('#goTest');
  await page.waitForFunction(()=>!document.getElementById('choose').classList.contains('hidden'));
  await page.click('[data-mode="jp-cn"]');
  await page.waitForFunction(()=>!document.getElementById('test').classList.contains('hidden'));
  assert.ok(await visible(page,'#answer'));
  await noOverflow(page,'Test');
  await page.screenshot({path:out+'/test.png'});
  assert.deepEqual(errors,[],'Uncaught JS errors');
  const dark=await browser.newPage();
  await dark.setViewport({width:390,height:844,isMobile:true,hasTouch:true,deviceScaleFactor:2});
  await dark.emulateMediaFeatures([{name:'prefers-color-scheme',value:'dark'},{name:'prefers-reduced-motion',value:'reduce'}]);
  await dark.goto(url,{waitUntil:'networkidle2',timeout:45000});
  await dark.waitForFunction(()=>Number(document.getElementById('totalWords')?.textContent)>700);
  const darkBg=await dark.$eval('body',e=>getComputedStyle(e).backgroundColor);
  assert.equal(darkBg,'rgb(0, 0, 0)','Dark mode needs native dark canvas');
  await noOverflow(dark,'Dark home');
  await dark.screenshot({path:out+'/home-dark.png',fullPage:true});
  console.log('KOTOBA iPHONE VISUAL PASS:',JSON.stringify({screens:['home-light','lessons','setup','study','test','home-dark'],nav,darkBg,wordCount:await page.$eval('#totalWords',e=>e.textContent)}));
 }finally{await browser.close()}
}
run().catch(e=>{console.error(e);process.exitCode=1});
