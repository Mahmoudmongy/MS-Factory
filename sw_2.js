
const CACHE='factory-manager-v4-final-3';
const ASSETS=[
  './',
  './index.html',
  './css/style.css',
  './js/app.js',
  './js/supabase.js',
  './manifest.json',
  './assets/icon.svg',
  './assets/icon-192.png',
  './assets/icon-512.png'
];
self.addEventListener('install', e=>{
  e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting()));
});
self.addEventListener('activate', e=>{
  e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch', e=>{
  const url=new URL(e.request.url);
  if(url.hostname.includes('supabase.co')){
    e.respondWith(fetch(e.request).catch(()=>new Response(JSON.stringify({error:'offline'}), {status:503, headers:{'Content-Type':'application/json'}})));
    return;
  }
  e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(resp=>{
    if(resp.ok && new URL(e.request.url).origin===self.location.origin){
      const clone=resp.clone();
      caches.open(CACHE).then(c=>c.put(e.request, clone));
    }
    return resp;
  }).catch(()=>caches.match('./index.html'))));
});
