const CACHE='ios-kotoba-preview-v2-20261124';
const FILES=[
 './','./index.html','./ios.css?v=2.0','./app.js?v=2.0','./manifest.webmanifest',
 '../kotoba/icon.svg','../kotoba/styles.css?v=7.1','../kotoba/book-data.js?v=5.1',
 '../kotoba/vocab-03-page08.js?v=7.0','../kotoba/vocab-04.js?v=7.0',
 '../kotoba/vocab-05.js?v=7.0','../kotoba/vocab-13.js?v=6.0',
 '../kotoba/vocab-14.js?v=6.0','../kotoba/vocab-15.js?v=6.0',
 '../kotoba/vocab-16.js?v=6.0','../kotoba/extra-words.js?v=6.1'
];
self.addEventListener('install',event=>{
 event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(FILES)).then(()=>self.skipWaiting()));
});
self.addEventListener('activate',event=>{
 event.waitUntil(caches.keys().then(keys=>Promise.all(
  keys.filter(key=>key.startsWith('ios-kotoba-preview-')&&key!==CACHE)
      .map(key=>caches.delete(key)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch',event=>{
 if(event.request.method!=='GET')return;
 const url=new URL(event.request.url);
 if(url.origin!==self.location.origin)return;
 event.respondWith(fetch(event.request).then(resp=>{
   if(resp.ok){const cloned=resp.clone();
     event.waitUntil(caches.open(CACHE).then(c=>c.put(event.request,cloned)).catch(()=>{}));}
   return resp;
 }).catch(async()=>{
   const cache=await caches.match(event.request);
   if(cache)return cache;
   return event.request.mode==='navigate'?await caches.match('./index.html')||Response.error():Response.error();
 }));
});
