
const SUPABASE_URL="https://bnvduwjisqosdjqypnvq.supabase.co";
const SUPABASE_ANON="sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv";
const C2_CLIENT_ID="bx8m9j1Qj8GZnN3ni8Wz5QEb15SHB9amysaSgelu";
const C2_SCOPE="user:read,results:read";
const C2_REDIRECT="https://rowtraining.vercel.app/concept2-callback.html";

async function authUser(req){
  const auth=req.headers.authorization||"";
  if(!auth.startsWith("Bearer ")) throw new Error("AUTH");
  const r=await fetch(`${SUPABASE_URL}/auth/v1/user`,{headers:{apikey:SUPABASE_ANON,Authorization:auth}});
  if(!r.ok) throw new Error("AUTH");
  return r.json();
}
async function rest(path,opts={}){
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!key) throw new Error("Falta SUPABASE_SERVICE_ROLE_KEY en Vercel.");
  return fetch(`${SUPABASE_URL}/rest/v1/${path}`,{
    ...opts,
    headers:{apikey:key,Authorization:`Bearer ${key}`,"Content-Type":"application/json",...(opts.headers||{})}
  });
}
function c2timeSeconds(v){ return v==null?null:Number(v)/10; }
function pace500(timeTenths,distance){
  if(!timeTenths||!distance)return null;
  return Math.round(((Number(timeTenths)/10)/Number(distance)*500)*10)/10;
}

module.exports=async function handler(req,res){
  if(req.method!=="POST")return res.status(405).json({error:"Método no permitido"});
  const secret=process.env.CONCEPT2_CLIENT_SECRET;
  if(!secret)return res.status(500).json({error:"Falta CONCEPT2_CLIENT_SECRET en Vercel."});
  try{
    const me=await authUser(req);
    const {code,redirect_uri}=req.body||{};
    if(!code||redirect_uri!==C2_REDIRECT)return res.status(400).json({error:"Solicitud OAuth no válida."});

    const body=new URLSearchParams({
      client_id:C2_CLIENT_ID,client_secret:secret,grant_type:"authorization_code",
      redirect_uri:C2_REDIRECT,code,scope:C2_SCOPE
    });
    const tr=await fetch("https://log.concept2.com/oauth/access_token",{
      method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded","Accept":"application/json"},body
    });
    const tok=await tr.json().catch(()=>({}));
    if(!tr.ok)return res.status(tr.status).json({error:tok.error_description||tok.error||"Concept2 rechazó la autorización."});
    const access=tok.access_token;
    const refresh=tok.refresh_token;
    if(!access||!refresh)return res.status(502).json({error:"Concept2 no devolvió los tokens esperados."});

    const c2h={Authorization:`Bearer ${access}`,Accept:"application/vnd.c2logbook.v1+json"};
    const ur=await fetch("https://log.concept2.com/api/users/me",{headers:c2h});
    const uj=await ur.json().catch(()=>({}));
    if(!ur.ok)return res.status(ur.status).json({error:uj.message||"No se pudo leer el perfil Concept2."});
    const u=uj.data||uj;
    const expiresAt=new Date(Date.now()+(Number(tok.expires_in)||604800)*1000).toISOString();

    const payload=[{
      user_id:me.id,concept2_user_id:String(u.id||""),concept2_username:u.username||u.name||null,
      access_token:access,refresh_token:refresh,expires_at:expiresAt,scope:C2_SCOPE,updated_at:new Date().toISOString()
    }];
    const sr=await rest("concept2_connections?on_conflict=user_id",{
      method:"POST",headers:{Prefer:"resolution=merge-duplicates,return=representation"},body:JSON.stringify(payload)
    });
    if(!sr.ok){
  const detail = await sr.text();
  console.error("Supabase concept2_connections:", sr.status, detail);
  return res.status(500).json({
    error:"Supabase rechazó el guardado: "+sr.status+" · "+detail
  });
}

    return res.json({ok:true,user:{id:u.id,username:u.username||u.name||null}});
  }catch(e){
    if(e.message==="AUTH")return res.status(401).json({error:"Sesión de Row Training no válida."});
    console.error(e); return res.status(500).json({error:e.message||"Error interno"});
  }
};
