// Row Training · service worker
// V548 · además de las notificaciones push (igual que antes), guarda la app en el móvil para que
// abra aunque no haya cobertura:
//  - La app (index.html): primero intenta la versión nueva de internet (como mucho 4 s); si no hay
//    red o tarda, abre la última guardada. Así las actualizaciones siguen llegando con normalidad.
//  - Librerías externas, fuentes, logo e imágenes: se sirven de lo guardado y se refrescan por detrás.
//  - Los datos (Supabase), /api/ y version.json NO pasan por aquí: siempre van directos a internet.
// V973 · al abrir: primero internet (máx. 2,5 s) y si no, la copia guardada; así una versión subida con la app cerrada se abre directamente.
// V952 · al pulsar una notificación con la app ya abierta, ya no se recarga la página (salía otra vez la
//  pantalla de inicio): se le pasa el enlace a la app y ella abre la pantalla que toca.
const CACHE='rowtraining-app-v565';
const PRECACHE=['/','/index.html','/manifest.json','/assets/club-pedregalejo.png','/assets/brand/logo-login-oscuro.png','/assets/brand/logo-login-claro.png','/assets/brand/icon-cabecera.png','/assets/brand/icon-192.png','/assets/brand/favicon-32.png'];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(c=>Promise.all(PRECACHE.map(u=>c.add(new Request(u,{cache:'reload'})).catch(()=>{})))).then(()=>self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('rowtraining-app-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});

// V980 · solo la app (/ o /index.html) pasa por aquí; otras páginas (p. ej. /zonas.html) van directas a internet
function isAppPage(req,url){
  return url.origin===self.location.origin&&(url.pathname==='/'||url.pathname==='/index.html');
}

async function appPage(req,url,event){
  const cache=await caches.open(CACHE);
  // V973 · se pide por la dirección (no con la petición de navegación tal cual: algunos navegadores no dejan
  // reutilizarla con opciones y entonces nunca se bajaba la versión nueva al abrir).
  const net=fetch(new Request(url.href,{cache:'no-store',credentials:'include',redirect:'follow'})).then(res=>{
    if(res&&res.ok)cache.put('/index.html',res.clone()).catch(()=>{});
    return res;
  });
  // V973 · al abrir la app se intenta primero la versión de internet (como mucho 1,5 s, mientras sale la
  // pantalla de inicio). Así, si has subido una versión con la app cerrada, se abre ya la nueva y no hace
  // falta el aviso. Sin cobertura o con red lenta se abre al momento la copia guardada, como antes.
  if(!url.searchParams.has('appv')){
    const hit=await cache.match('/index.html')||await cache.match('/');
    if(hit){
      // V997 · antes bastaba con que llegaran las cabeceras en 2,5 s: con poca cobertura el resto (la app pesa ~2 MB) seguía
      // bajando lento y la pantalla se quedaba en blanco. Ahora la versión de internet solo se usa si llega ENTERA en 1,5 s.
      const full=net.then(async res=>{if(!res||!res.ok)return null;const buf=await res.clone().arrayBuffer();return new Response(buf,{status:200,headers:res.headers})}).catch(()=>null);
      const quick=await Promise.race([full,new Promise(r=>setTimeout(()=>r(null),1500))]);
      if(quick&&quick.ok)return quick;
      if(event)event.waitUntil(net.catch(()=>{}));else net.catch(()=>{});
      return hit;
    }
  }
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
  // V800 · compartir desde otra app (Android): guarda el archivo y abre la app en Mensajes
  if(req.method==='POST'&&new URL(req.url).pathname==='/share-target'){
    event.respondWith((async()=>{
      try{
        const fd=await req.formData(),cache=await caches.open('rowtraining-share');
        for(const k of await cache.keys())await cache.delete(k);
        const f=fd.get('file');
        if(f&&f.size)await cache.put('/__share/file',new Response(f,{headers:{'Content-Type':f.type||'application/octet-stream','X-Name':encodeURIComponent(f.name||'archivo')}}));
        await cache.put('/__share/meta',new Response(JSON.stringify({title:fd.get('title')||'',text:fd.get('text')||'',url:fd.get('url')||''}),{headers:{'Content-Type':'application/json'}}));
      }catch(e){}
      return Response.redirect('/?tab=mensajes&share=1',303);
    })());
    return;
  }
  if(req.method!=='GET')return;
  let url;try{url=new URL(req.url)}catch(e){return}
  if(url.protocol!=='https:'&&url.protocol!=='http:')return;
  // datos y servicios: siempre directos a internet
  if(/supabase\.co$/.test(url.hostname))return;
  if(url.origin===self.location.origin&&(url.pathname.startsWith('/api/')||url.pathname==='/version.json'||url.pathname==='/sw.js'))return;
  if(isAppPage(req,url)){event.respondWith(appPage(req,url,event));return}
  const cdn=/(^|\.)cdn\.jsdelivr\.net$|(^|\.)unpkg\.com$|(^|\.)fonts\.googleapis\.com$|(^|\.)fonts\.gstatic\.com$/.test(url.hostname);
  const ownStatic=url.origin===self.location.origin&&(url.pathname.startsWith('/assets/')||url.pathname==='/manifest.json'||/\.(png|jpg|jpeg|webp|svg|ico|woff2?)$/i.test(url.pathname));
  if(cdn||ownStatic){event.respondWith(staleWhileRevalidate(req));return}
});

// V890 · si el sistema cambia o caduca la suscripción push, se avisa a la app para que se registre de nuevo
self.addEventListener('pushsubscriptionchange', event => {
  event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{list.forEach(c=>c.postMessage({type:'push-resubscribe'}))}).catch(()=>{}));
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
    const item={title:data.title||'Row Training',body:data.body||'',url:data.url||'/',ts:Date.now()};
    // V990 · el servidor a veces manda el mismo aviso dos veces (un solo mensaje → dos pushes): si ya hay uno idéntico
    // de hace menos de 45 segundos no se añade otra vez a la lista.
    const dup=prev.some(p=>p&&p.title===item.title&&p.body===item.body&&p.url===item.url&&(item.ts-(p.ts||0))<45000);
    const items=(dup?prev:[item,...prev]).slice(0,8);
    const n=items.length;
    const one=n===1;
    try{if(typeof data.badge==='number'&&self.navigator&&self.navigator.setAppBadge){if(data.badge>0)await self.navigator.setAppBadge(data.badge);else await self.navigator.clearAppBadge()}}catch(e){} // V731 · globo del icono
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
  })().catch(async()=>{
    // V890 · pase lo que pase, SIEMPRE se muestra un aviso (si no, iOS acaba cancelando las notificaciones de ese móvil)
    try{await self.registration.showNotification(data.title||'Row Training',{body:data.body||'',icon:'/assets/brand/icon-192.png',data:{url:data.url||'/'}})}catch(e){}
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target=new URL(event.notification.data?.url||'/',self.location.origin).href;
  event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{
    // V952 · si la app ya está abierta: se enfoca y se le pasa el enlace (sin recargar). Si no, se abre.
    for(const c of list){
      if('focus' in c){
        try{c.postMessage({type:'open-url',url:target})}catch(e){}
        return c.focus().catch(()=>null);
      }
    }
    return clients.openWindow?clients.openWindow(target):null;
  }));
});
