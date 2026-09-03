self.addEventListener('push', event => {
  let data={};
  try{ data=event.data?event.data.json():{}; }catch(e){ data={title:'Row Training',body:event.data?.text?.()||''}; }
  const title=data.title||'Row Training';
  const options={
    body:data.body||'',
    icon:'/assets/club-pedregalejo.png',
    badge:'/assets/club-pedregalejo.png',
    data:{url:data.url||'/'},
    tag:data.tag||undefined,
    renotify:true
  };
  event.waitUntil(self.registration.showNotification(title,options));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target=new URL(event.notification.data?.url||'/',self.location.origin).href;
  event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{
    for(const c of list){ if('focus' in c){ c.navigate(target); return c.focus(); } }
    return clients.openWindow?clients.openWindow(target):null;
  }));
});
