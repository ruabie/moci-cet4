const CACHE='kotoba-v6.1-20261111-extras';
const FILES=['./','./index.html','./styles.css?v=6.1','./book-data.js?v=5.1',
  './vocab-13.js?v=6.0','./vocab-14.js?v=6.0','./vocab-15.js?v=6.0','./vocab-16.js?v=6.0',
  './extra-words.js?v=6.1','./app.js?v=6.1','./manifest.webmanifest','./icon.svg'];
self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(FILES)).then(()=>self.skipWaiting()));
});
self.addEventListener('activate',event=>{
  event.waitUntil(caches.keys()
    .then(keys=>Promise.all(keys.filter(key=>key.startsWith('kotoba-')&&key!==CACHE).map(key=>caches.delete(key))))
    .then(()=>self.clients.claim()));
});
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;
  const url=new URL(event.request.url);
  if(url.origin!==self.location.origin)return;
  event.respondWith(
    fetch(event.request).then(response=>{
      if(response&&response.ok){
        const copy=response.clone();
        event.waitUntil(caches.open(CACHE).then(cache=>cache.put(event.request,copy)).catch(()=>{}));
      }
      return response;
    }).catch(async()=>{
      const cached=await caches.match(event.request);
      if(cached)return cached;
      if(event.request.mode==='navigate')return caches.match('./index.html')||Response.error();
      // Never answer missing JavaScript with HTML; it hides real data-loading errors.
      return Response.error();
    })
  );
});
