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
async function rest(path){
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!key)throw new Error("Falta SUPABASE_SERVICE_ROLE_KEY en Vercel.");
  return fetchTimed(`${SUPABASE_URL}/rest/v1/${path}`,{headers:{apikey:key,Authorization:`Bearer ${key}`,Accept:"application/json"}});
}
async function isGlobalCoach(userId){
  const r=await rest(`user_roles?user_id=eq.${encodeURIComponent(userId)}&select=role&limit=1`);
  if(!r.ok)return false;
  const rows=await r.json();
  return rows.some(x=>String(x.role||"").toLowerCase()==="coach");
}
async function findSubscriptions(){
  const candidates=["push_subscriptions","web_push_subscriptions","notification_subscriptions","push_devices","user_push_subscriptions","app_push_subscriptions"];
  for(const table of candidates){
    const r=await rest(`${table}?select=user_id&limit=10000`);
    if(r.ok){
      const rows=await r.json();
      return Array.isArray(rows)?rows:[];
    }
    if(r.status!==404&&r.status!==400){
      const txt=await r.text().catch(()=>"");
      throw new Error(txt||`No se pudo consultar ${table}.`);
    }
  }
  throw new Error("No se ha localizado la tabla de suscripciones push.");
}
module.exports=async(req,res)=>{
  if(req.method!=="GET")return res.status(405).json({error:"Método no permitido"});
  try{
    const user=await authUser(req);
    if(!await isGlobalCoach(user.id))return res.status(403).json({error:"Solo disponible para administrador"});
    const rows=await findSubscriptions();
    const counts=new Map();
    for(const x of rows){if(!x?.user_id)continue;const k=String(x.user_id);counts.set(k,(counts.get(k)||0)+1)}
    return res.status(200).json({ok:true,users:[...counts].map(([user_id,devices])=>({user_id,devices}))});
  }catch(e){
    if(e.message==="AUTH")return res.status(401).json({error:"Sesión no válida"});
    return res.status(500).json({error:e.message||"No se pudo consultar el estado push"});
  }
};
