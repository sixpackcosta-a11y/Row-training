const webpush=require("web-push");
const SUPABASE_URL=process.env.SUPABASE_URL||"https://bnvduwjisqosdjqypnvq.supabase.co";
const SUPABASE_ANON=process.env.SUPABASE_ANON_KEY||"sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv";
const TABLE="push_subscriptions";

async function fetchTimed(url,opts={},ms=10000){
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),ms);
  try{return await fetch(url,{...opts,signal:controller.signal})}finally{clearTimeout(timer)}
}
async function authUser(req){
  const auth=req.headers.authorization||"";
  if(!auth.startsWith("Bearer "))throw new Error("AUTH");
  const r=await fetchTimed(`${SUPABASE_URL}/auth/v1/user`,{headers:{apikey:SUPABASE_ANON,Authorization:auth}});
  if(!r.ok)throw new Error("AUTH");
  return r.json();
}
// V890 · una petición a Supabase con 1 reintento si falla por red o por error del servidor
async function rest(path,opts={}){
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!key)throw new Error("Falta SUPABASE_SERVICE_ROLE_KEY en Vercel.");
  const headers={apikey:key,Authorization:`Bearer ${key}`,Accept:"application/json",...(opts.headers||{})};
  if(opts.body!==undefined&&!headers["Content-Type"])headers["Content-Type"]="application/json";
  let last=null;
  for(let i=0;i<2;i++){
    try{const r=await fetchTimed(`${SUPABASE_URL}/rest/v1/${path}`,{...opts,headers});if(r.status<500)return r;last=r}
    catch(e){last=e}
    await new Promise(r=>setTimeout(r,400));
  }
  if(last&&last.ok===false)return last;
  throw last||new Error("Supabase no responde");
}
async function isGlobalCoach(userId){
  const r=await rest(`user_roles?user_id=eq.${encodeURIComponent(userId)}&select=role&limit=1`);
  if(!r.ok)return false;
  const rows=await r.json().catch(()=>[]);
  return rows.some(x=>String(x.role||"").toLowerCase()==="coach");
}
// V890 · UN solo guardado atómico (upsert por endpoint, que ya es único en la tabla). Antes se buscaba
// la tabla y sus columnas en cada llamada y se hacía "buscar y luego insertar", lo que fallaba si la app
// mandaba dos registros a la vez (arranque + reanudar) y tardaba mucho con muchos móviles abriendo a la vez.
async function saveSubscription(user,sub,ua){
  if(!sub?.endpoint)throw new Error("Suscripción push incompleta: falta endpoint.");
  const payload={user_id:user.id,endpoint:sub.endpoint,p256dh:sub.keys?.p256dh||null,auth:sub.keys?.auth||null,user_agent:String(ua||"").slice(0,300)||null,updated_at:new Date().toISOString()};
  const r=await rest(`${TABLE}?on_conflict=endpoint`,{method:"POST",headers:{Prefer:"resolution=merge-duplicates,return=minimal"},body:JSON.stringify(payload)});
  if(r.ok)return;
  const txt=await r.text().catch(()=>"");
  throw new Error(txt||"No se pudo guardar la suscripción push.");
}
async function removeSubscription(user,endpoint){
  if(!endpoint)return;
  const r=await rest(`${TABLE}?user_id=eq.${encodeURIComponent(user.id)}&endpoint=eq.${encodeURIComponent(endpoint)}`,{method:"DELETE",headers:{Prefer:"return=minimal"}});
  if(!r.ok){const txt=await r.text().catch(()=>"");throw new Error(txt||"No se pudo borrar la suscripción push.")}
}
async function statusForCoach(user){
  if(!await isGlobalCoach(user.id))return {status:403,body:{error:"Solo disponible para administrador"}};
  const r=await rest(`${TABLE}?select=user_id&limit=10000`);
  if(!r.ok){const txt=await r.text().catch(()=>"");throw new Error(txt||"No se pudo consultar el estado push.")}
  const rows=await r.json().catch(()=>[]),counts=new Map();
  for(const x of rows){if(!x?.user_id)continue;const k=String(x.user_id);counts.set(k,(counts.get(k)||0)+1)}
  return {status:200,body:{ok:true,users:[...counts].map(([user_id,devices])=>({user_id,devices}))}};
}

// V892 · prueba de envío (antes en api/push-test.js; se junta aquí para no pasar el límite de 12 funciones de Vercel Hobby)
async function sendTest(user){
  const pub=process.env.VAPID_PUBLIC_KEY,priv=process.env.VAPID_PRIVATE_KEY;
  if(!pub||!priv)return {error:"push_not_configured"};
  const q=await rest(`${TABLE}?user_id=eq.${encodeURIComponent(user.id)}&select=id,endpoint,p256dh,auth`);
  if(!q.ok)throw new Error("supabase_"+q.status);
  const subs=await q.json();
  webpush.setVapidDetails("https://rowtraining.vercel.app",pub,priv);
  let sent=0;const errors=[];
  await Promise.all(subs.map(async ps=>{
    try{
      await webpush.sendNotification({endpoint:ps.endpoint,keys:{p256dh:ps.p256dh,auth:ps.auth}},JSON.stringify({title:"🔔 Prueba de Row Training",body:"Si ves este aviso, las notificaciones funcionan en este dispositivo.",url:"/",tag:"rowtraining-test"}),{TTL:600,urgency:"high",timeout:8000});
      sent++;
    }catch(e){
      errors.push({statusCode:e?.statusCode||null,message:String(e?.body||e?.message||e).slice(0,200)});
      if(e?.statusCode===404||e?.statusCode===410){try{await rest(`${TABLE}?id=eq.${ps.id}`,{method:"DELETE",headers:{Prefer:"return=minimal"}})}catch(_){}}
    }
  }));
  return {ok:true,found:subs.length,sent,errors};
}

module.exports=async(req,res)=>{
  if(req.method!=="POST")return res.status(405).json({error:"Método no permitido"});
  try{
    const user=await authUser(req);
    const body=req.body&&typeof req.body==="object"?req.body:{};
    if(body.action==="status"){
      const out=await statusForCoach(user);
      return res.status(out.status).json(out.body);
    }
    if(body.action==="test"){
      return res.status(200).json(await sendTest(user));
    }
    if(body.action==="unsubscribe"){
      await removeSubscription(user,body.endpoint);
      return res.status(200).json({ok:true});
    }
    const sub=body.subscription;
    if(!sub?.endpoint)return res.status(400).json({error:"Falta la suscripción push"});
    await saveSubscription(user,sub,req.headers["user-agent"]);
    return res.status(200).json({ok:true});
  }catch(e){
    if(e.message==="AUTH")return res.status(401).json({error:"Sesión no válida"});
    if(e?.name==="AbortError")return res.status(504).json({error:"La operación está tardando demasiado"});
    console.error(e);return res.status(500).json({error:e.message||"Error interno"});
  }
};
