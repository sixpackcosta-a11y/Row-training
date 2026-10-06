// Row Training · service worker
// V548 · además de las notificaciones push (igual que antes), guarda la app en el móvil para que
// abra aunque no haya cobertura:
//  - La app (index.html): primero intenta la versión nueva de internet (como mucho 4 s); si no hay
//    red o tarda, abre la última guardada. Así las actualizaciones siguen llegando con normalidad.
//  - Librerías externas, fuentes, logo e imágenes: se sirven de lo guardado y se refrescan por detrás.
//  - Los datos (Supabase), /api/ y version.json NO pasan por aquí: siempre van directos a internet.
const CACHE='rowtraining-app-v562';
const PRECACHE=['/','/index.html','/manifest.json','/assets/club-pedregalejo.png','/assets/brand/logo-login-oscuro.png','/assets/brand/logo-login-claro.png','/assets/brand/icon-cabecera.png','/assets/brand/icon-192.png','/assets/brand/favicon-32.png'];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(c=>Promise.all(PRECACHE.map(u=>c.add(new Request(u,{cache:'reload'})).catch(()=>{})))).then(()=>self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('rowtraining-app-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});

function isAppPage(req,url){
  return req.mode==='navigate'||(url.origin===self.location.origin&&(url.pathname==='/'||url.pathname==='/index.html'));
}

async function appPage(req,url){
  const cache=await caches.open(CACHE);
  const net=fetch(req,{cache:'no-store'}).then(res=>{
    if(res&&res.ok)cache.put('/index.html',res.clone()).catch(()=>{});
    return res;
  });
  // tras avisar de una versión nueva (?appv=…) se espera más a la red para no abrir la vieja
  const timeout=new Promise(resolve=>setTimeout(()=>resolve(null),url.searchParams.has('appv')?15000:4000));
  try{
    const res=await Promise.race([net,timeout]);
    if(res&&res.ok)return res;
  }catch(e){}
  const cached=await cache.match('/index.html')||await cache.match('/');
  if(cached)return cached;
  return net; // primera vez sin nada guardado: esperar a la red
}

async function staleWhileRevalidate(req){
  const cache=await caches.open(CACHE);
  const cached=await cache.match(req);
  const net=fetch(req).then(res=>{
    if(res&&(res.ok||res.type==='opaque'))cache.put(req,res.clone()).catch(()=>{});
    return res;
  }).catch(()=>null);
  if(cached){net.catch(()=>{});return cached}
  const res=await net;
  return res||new Response('',{status:504});
}

self.addEventListener('fetch', event => {
  const req=event.request;
  if(req.method!=='GET')return;
  let url;try{url=new URL(req.url)}catch(e){return}
  if(url.protocol!=='https:'&&url.protocol!=='http:')return;
  // datos y servicios: siempre directos a internet
  if(/supabase\.co$/.test(url.hostname))return;
  if(url.origin===self.location.origin&&(url.pathname.startsWith('/api/')||url.pathname==='/version.json'||url.pathname==='/sw.js'))return;
  if(isAppPage(req,url)){event.respondWith(appPage(req,url));return}
  const cdn=/(^|\.)cdn\.jsdelivr\.net$|(^|\.)unpkg\.com$|(^|\.)fonts\.googleapis\.com$|(^|\.)fonts\.gstatic\.com$/.test(url.hostname);
  const ownStatic=url.origin===self.location.origin&&(url.pathname.startsWith('/assets/')||url.pathname==='/manifest.json'||/\.(png|jpg|jpeg|webp|svg|ico|woff2?)$/i.test(url.pathname));
  if(cdn||ownStatic){event.respondWith(staleWhileRevalidate(req));return}
});

self.addEventListener('push', event => {
  let data={};
  try{ data=event.data?event.data.json():{}; }catch(e){ data={title:'Row Training',body:event.data?.text?.()||''}; }
  // V666 · agrupación: todos los avisos sin abrir se funden en UNA sola notificación
  // ("N avisos nuevos") que al desplegarse lista cada uno.
  event.waitUntil((async()=>{
    const GROUP='rowtraining-group';
    let prev=[],old=[];
    try{old=await self.registration.getNotifications({tag:GROUP});old.sort((x,y)=>(y.timestamp||0)-(x.timestamp||0));prev=old[0]?.data?.items||[]}catch(e){}
    const item={title:data.title||'Row Training',body:data.body||'',url:data.url||'/'};
    const items=[item,...prev].slice(0,8);
    const n=items.length;
    const one=n===1;
    await self.registration.showNotification(one?item.title:`Row Training · ${n} avisos nuevos`,{
      body:one?item.body:items.slice(0,6).map(i=>'• '+(i.body||i.title)).join('\n'),
      icon:'/assets/brand/icon-192.png',
      badge:'/assets/brand/badge-96.png',
      data:{url:one?item.url:'/',items},
      tag:GROUP,
      renotify:true
    });
    // iOS no reemplaza por etiqueta: se cierran las agrupaciones anteriores para que no se apilen
    try{old.forEach(n=>n.close())}catch(e){}
  })());
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target=new URL(event.notification.data?.url||'/',self.location.origin).href;
  event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{
    for(const c of list){ if('focus' in c){ c.navigate(target); return c.focus(); } }
    return clients.openWindow?clients.openWindow(target):null;
  }));
});
