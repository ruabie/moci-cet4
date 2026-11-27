#!/usr/bin/env node
// Browser smoke test, never a claim of native Windows GPU validation.
// Must load real Godot JS+WASM+PCK from the local isolated build.
import fs from "node:fs";
import process from "node:process";
const {chromium} = await import(process.env.PLAYWRIGHT_ROOT + "/node_modules/playwright/index.mjs");
const base=process.env.PREVIEW_URL ?? "http://127.0.0.1:8765/?qa=1";
const dir=process.env.PREVIEW_EVIDENCE ?? "v039-web-browser-evidence";
fs.mkdirSync(dir,{recursive:true});
let browser;
const outcome={version:"V0.39",url:base,engineBoot:false,wasmStarted:false,realKeyboardMovement:false,
  actualWebScreenshot:false,webGL2Available:false,notWindowsGPU:true,notHumanQA:true,qaOnlyPreview:true,
  logs:[],errors:[],browser:"Playwright Chromium headless",pass:false};
try{
  browser=await chromium.launch({headless:true,args:[
    "--use-gl=angle","--use-angle=swiftshader","--enable-webgl","--ignore-gpu-blocklist",
    "--enable-unsafe-swiftshader"
  ]});
  const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
  const page=await context.newPage();
  page.on("pageerror",e=>outcome.errors.push("pageerror: "+e.message));
  page.on("console",m=>{if(m.type()==="error")outcome.errors.push("console: "+m.text());else if(outcome.logs.length<30)outcome.logs.push(m.text().slice(0,300));});
  page.on("requestfailed",req=>outcome.errors.push("requestfailed: "+req.url()+" "+(req.failure()?.errorText??"")));
  const resp=await page.goto(base,{waitUntil:"domcontentloaded",timeout:50000});
  if(!resp||resp.status()!=200)throw Error("HTML returned HTTP "+(resp?.status()??"missing"));
  await page.waitForFunction(()=>!!(globalThis.__LIFESIM_QA__ && typeof globalThis.__LIFESIM_QA__.getState==="function"),
    {timeout:120000});
  const init=await page.evaluate(()=>{
    const c=document.querySelector("canvas");
    const s=window.__LIFESIM_QA__.getState();
    return {x:s.x,y:s.y,z:s.z,balance:s.balance,indoor:s.indoor,
       canvasExists:!!c,canvasWidth:c?.width,canvasHeight:c?.height,
       isCrossOriginIsolated:crossOriginIsolated,
       webglContextExists:!!(c?.getContext("webgl2")||c?.getContext("webgl"))
    };
  });
  outcome.initialState=init;
  outcome.engineBoot=init.canvasExists&&typeof init.x==="number"&&typeof init.balance==="number";
  outcome.wasmStarted=outcome.engineBoot;
  outcome.webGL2Available=init.webglContextExists;
  if(!outcome.engineBoot||!outcome.webGL2Available)throw Error("real WebAssembly game did not provide a working canvas+QA state");
  await page.screenshot({path:dir+"/v039_chromium_loaded.png",timeout:40000});
  outcome.actualWebScreenshot=fs.statSync(dir+"/v039_chromium_loaded.png").size>12000;
  // Dispatch via actual browser key input to canvas. No direct state writes.
  // Godot pointer-lock click can trigger browser navigation scheduling.\n  // Send a real physical browser pointer event without locator navigation waits.\n  await page.mouse.click(580,330);
  await page.keyboard.down("w");
  await page.waitForTimeout(1400);
  await page.keyboard.up("w");
  await page.waitForTimeout(250);
  const moved=await page.evaluate(()=>window.__LIFESIM_QA__.getState());
  outcome.afterRealWKey={x:moved.x,y:moved.y,z:moved.z};
  const amount=Math.hypot(moved.x-init.x,moved.z-init.z);
  outcome.travelledMetres=amount;
  outcome.realKeyboardMovement=amount>0.15 && amount<30;
  await page.screenshot({path:dir+"/v039_chromium_after_w.png",timeout:40000});
  outcome.actualWebScreenshot=outcome.actualWebScreenshot && fs.statSync(dir+"/v039_chromium_after_w.png").size>12000;
  outcome.pass=outcome.engineBoot && outcome.webGL2Available &&
    outcome.realKeyboardMovement && outcome.actualWebScreenshot;
  if(!outcome.pass)throw Error("Web export loaded but original CityPlayer did not move correctly under browser W or screenshot invalid; metres="+amount);
  console.log("V039 REAL CHROMIUM GODOT WEB BOOT AND W KEY PASS:",JSON.stringify({
    travelledMetres:amount,screenshotCount:2,canvas:[init.canvasWidth,init.canvasHeight],
    crossOriginIsolated:init.isCrossOriginIsolated,wasmStarted:outcome.wasmStarted}));
} catch(err){
  outcome.errors.push(String(err?.stack??err));
  console.error("V039 REAL CHROMIUM GODOT WEB BOOT FAIL:",String(err));
  process.exitCode=1;
} finally{
  fs.writeFileSync(dir+"/v039_chromium_metrics.json",JSON.stringify(outcome,null,2)+"\n");
  await browser?.close().catch(()=>{});
}
