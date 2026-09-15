const SUPABASE_URL=process.env.SUPABASE_URL||"https://bnvduwjisqosdjqypnvq.supabase.co";
const SUPABASE_ANON=process.env.SUPABASE_ANON_KEY||"sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv";

async function fetchTimed(url,opts={},ms=12000){
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
async function rest(path,opts={}){
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!key)throw new Error("Falta SUPABASE_SERVICE_ROLE_KEY en Vercel.");
  const headers={apikey:key,Authorization:`Bearer ${key}`,Accept:"application/json",...(opts.headers||{})};
  if(opts.body!==undefined&&!headers["Content-Type"])headers["Content-Type"]="application/json";
  return fetchTimed(`${SUPABASE_URL}/rest/v1/${path}`,{...opts,headers});
}
async function isGlobalCoach(userId){
  const r=await rest(`user_roles?user_id=eq.${encodeURIComponent(userId)}&select=role&limit=1`);
  if(!r.ok)return false;
  const rows=await r.json().catch(()=>[]);
  return rows.some(x=>String(x.role||"").toLowerCase()==="coach");
}
const PUSH_TABLES=["push_subscriptions","web_push_subscriptions","notification_subscriptions","push_devices","user_push_subscriptions","app_push_subscriptions"];
async function findPushTable(){
  for(const table of PUSH_TABLES){
    const r=await rest(`${table}?select=*&limit=1`);
    if(r.ok)return {table,sample:(await r.json().catch(()=>[]))[0]||null};
    if(r.status!==404&&r.status!==400){
      const txt=await r.text().catch(()=>"");
      throw new Error(txt||`No se pudo consultar ${table}.`);
    }
  }
  throw new Error("No se ha localizado la tabla de suscripciones push.");
}
async function openApiColumns(table){
  try{
    const r=await rest("",{headers:{Accept:"application/openapi+json"}});
    if(!r.ok)return null;
    const j=await r.json();
    const def=j?.definitions?.[table]||j?.components?.schemas?.[table];
    const props=def?.properties?Object.keys(def.properties):[];
    return props.length?new Set(props):null;
  }catch(e){return null}
}
function payloadFor(cols,user,sub){
  const has=k=>!cols||cols.has(k),now=new Date().toISOString();
  const p={};
  if(has("user_id"))p.user_id=user.id;
  if(has("endpoint"))p.endpoint=sub.endpoint;
  if(has("p256dh"))p.p256dh=sub.keys?.p256dh||null;
  if(has("auth"))p.auth=sub.keys?.auth||null;
  if(has("keys"))p.keys=sub.keys||{};
  if(has("subscription"))p.subscription=sub;
  if(has("subscription_json"))p.subscription_json=sub;
  if(has("expiration_time"))p.expiration_time=sub.expirationTime??null;
  if(has("expirationTime"))p.expirationTime=sub.expirationTime??null;
  if(has("updated_at"))p.updated_at=now;
  return p;
}
function rowEndpoint(row){
  return row?.endpoint||row?.subscription?.endpoint||row?.subscription_json?.endpoint||null;
}
async function saveSubscription(table,cols,user,sub){
  const payload=payloadFor(cols,user,sub);
  if(!payload.user_id)payload.user_id=user.id;
  if(!sub?.endpoint)throw new Error("Suscripción push incompleta: falta endpoint.");

  let existing=null;
  if(!cols||cols.has("endpoint")){
    const q=await rest(`${table}?endpoint=eq.${encodeURIComponent(sub.endpoint)}&select=*&limit=1`);
    if(q.ok)existing=(await q.json().catch(()=>[]))[0]||null;
  }
  if(!existing){
    const q=await rest(`${table}?user_id=eq.${encodeURIComponent(user.id)}&select=*`);
    if(q.ok){const rows=await q.json().catch(()=>[]);existing=rows.find(x=>rowEndpoint(x)===sub.endpoint)||null}
  }

  if(existing){
    let filter="";
    if(existing.id!=null)filter=`id=eq.${encodeURIComponent(existing.id)}`;
    else if(existing.endpoint)filter=`endpoint=eq.${encodeURIComponent(existing.endpoint)}`;
    if(filter){
      const r=await rest(`${table}?${filter}`,{method:"PATCH",headers:{Prefer:"return=minimal"},body:JSON.stringify(payload)});
      if(r.ok)return;
      const txt=await r.text().catch(()=>"");
      throw new Error(txt||"No se pudo actualizar la suscripción push.");
    }
  }

  const r=await rest(table,{method:"POST",headers:{Prefer:"return=minimal"},body:JSON.stringify(payload)});
  if(r.ok)return;
  const txt=await r.text().catch(()=>"");
  throw new Error(txt||"No se pudo guardar la suscripción push.");
}
async function statusForCoach(user){
  if(!await isGlobalCoach(user.id))return {status:403,body:{error:"Solo disponible para administrador"}};
  const {table}=await findPushTable();
  const r=await rest(`${table}?select=user_id&limit=10000`);
  if(!r.ok){const txt=await r.text().catch(()=>"");throw new Error(txt||"No se pudo consultar el estado push.")}
  const rows=await r.json().catch(()=>[]),counts=new Map();
  for(const x of rows){if(!x?.user_id)continue;const k=String(x.user_id);counts.set(k,(counts.get(k)||0)+1)}
  return {status:200,body:{ok:true,users:[...counts].map(([user_id,devices])=>({user_id,devices}))}};
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
    const sub=body.subscription;
    if(!sub?.endpoint)return res.status(400).json({error:"Falta la suscripción push"});
    const found=await findPushTable();
    const cols=await openApiColumns(found.table)||new Set(Object.keys(found.sample||{}));
    await saveSubscription(found.table,cols.size?cols:null,user,sub);
    return res.status(200).json({ok:true});
  }catch(e){
    if(e.message==="AUTH")return res.status(401).json({error:"Sesión no válida"});
    if(e?.name==="AbortError")return res.status(504).json({error:"La operación está tardando demasiado"});
    console.error(e);return res.status(500).json({error:e.message||"Error interno"});
  }
};
