
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

async function connection(userId){
  const r=await rest(`concept2_connections?user_id=eq.${encodeURIComponent(userId)}&select=*`);
  if(!r.ok)throw new Error("No se pudo leer la conexión Concept2.");
  const a=await r.json(); return a[0]||null;
}
async function validToken(c){
  if(new Date(c.expires_at).getTime()>Date.now()+60000)return c.access_token;
  const secret=process.env.CONCEPT2_CLIENT_SECRET;
  const body=new URLSearchParams({
    client_id:C2_CLIENT_ID,client_secret:secret,grant_type:"refresh_token",
    refresh_token:c.refresh_token,scope:C2_SCOPE
  });
  const r=await fetch("https://log.concept2.com/oauth/access_token",{
    method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded","Accept":"application/json"},body
  });
  const j=await r.json().catch(()=>({}));
  if(!r.ok)throw new Error(j.error_description||"Hay que volver a conectar Concept2.");
  const expiresAt=new Date(Date.now()+(Number(j.expires_in)||604800)*1000).toISOString();
  await rest(`concept2_connections?user_id=eq.${encodeURIComponent(c.user_id)}`,{
    method:"PATCH",body:JSON.stringify({
      access_token:j.access_token,refresh_token:j.refresh_token||c.refresh_token,expires_at:expiresAt,updated_at:new Date().toISOString()
    })
  });
  return j.access_token;
}
function dateOnly(v){return String(v||"").slice(0,10)}
function resultSeconds(result){
  if(result.time==null)return null;
  return Number(result.time)/10;
}
function scoreResult(result,intents){
  let best=null;
  for(const i of intents){
    let score=0;
    // La fecha es la señal principal, pero nunca basta por sí sola.
    if(dateOnly(result.date||result.date_utc)===i.scheduled_date)score+=45;

    const d=Number(result.distance||0);
    if(i.expected_distance_m&&d){
      const diff=Math.abs(d-i.expected_distance_m)/i.expected_distance_m;
      if(diff<=.03)score+=25; else if(diff<=.10)score+=15;
    }

    const secs=resultSeconds(result);
    if(i.expected_duration_seconds&&secs){
      const diff=Math.abs(secs-i.expected_duration_seconds)/i.expected_duration_seconds;
      if(diff<=.02)score+=25; else if(diff<=.08)score+=15; else if(diff<=.15)score+=8;
    }

    const spm=Number(result.stroke_rate||0);
    if(i.expected_spm&&spm){
      const diff=Math.abs(spm-i.expected_spm);
      if(diff<=1)score+=15; else if(diff<=3)score+=8;
    }

    if(i.expected_workout_type&&String(result.workout_type||"").toLowerCase().includes(String(i.expected_workout_type).toLowerCase()))score+=15;
    if(!best||score>best.score)best={intent:i,score};
  }
  if(!best||best.score<60)return {status:"unplanned",confidence:Math.min(best?.score||0,100),code:null,intentId:null};
  if(best.score>=80)return {status:"matched",confidence:Math.min(best.score,100),code:best.intent.session_code,intentId:best.intent.id};
  return {status:"review",confidence:Math.min(best.score,100),code:best.intent.session_code,intentId:best.intent.id};
}
module.exports=async function handler(req,res){
  try{
    const me=await authUser(req);
    const c=await connection(me.id);
    if(req.method==="GET"){
      return res.json({connected:!!c,username:c?.concept2_username||null,last_sync_at:c?.last_sync_at||null});
    }
    if(req.method!=="POST")return res.status(405).json({error:"Método no permitido"});
    if(!c)return res.status(409).json({error:"Primero conecta tu cuenta Concept2."});

    const token=await validToken(c);
    const limit=Math.min(Math.max(Number(req.body?.limit)||50,1),250);
    const rr=await fetch(`https://log.concept2.com/api/users/me/results?type=rower&number=${limit}`,{
      headers:{Authorization:`Bearer ${token}`,Accept:"application/vnd.c2logbook.v1+json"}
    });
    const rj=await rr.json().catch(()=>({}));
    if(!rr.ok)return res.status(rr.status).json({error:rj.message||"No se pudieron leer resultados de Concept2."});
    const results=Array.isArray(rj)?rj:(rj.data||[]);

    const ir=await rest(`ergo_intents?user_id=eq.${encodeURIComponent(me.id)}&select=*&order=scheduled_date.desc`);
    const intents=ir.ok?await ir.json():[];

    let imported=0,updated=0;
    for(const x of results){
      const match=scoreResult(x,intents);
      const row=[{
        user_id:me.id,concept2_result_id:String(x.id),workout_date:x.date||x.date_utc,
        distance_m:x.distance==null?null:Number(x.distance),
        time_tenths:x.time==null?null:Number(x.time),time_formatted:x.time_formatted||null,
        pace_500_seconds:pace500(x.time,x.distance),spm:x.stroke_rate==null?null:Number(x.stroke_rate),
        avg_hr:x.heart_rate?.average??null,max_hr:x.heart_rate?.max??null,
        workout_type:x.workout_type||null,source:x.source||null,
        matched_intent_id:match.intentId,matched_session_code:match.code,
        match_status:match.status,match_confidence:match.confidence,
        raw_result:x,updated_at:new Date().toISOString()
      }];
      const check=await rest(`concept2_results?user_id=eq.${encodeURIComponent(me.id)}&concept2_result_id=eq.${encodeURIComponent(String(x.id))}&select=id`);
      const existed=check.ok&&(await check.json()).length>0;
      const up=await rest("concept2_results?on_conflict=user_id,concept2_result_id",{
        method:"POST",headers:{Prefer:"resolution=merge-duplicates"},body:JSON.stringify(row)
      });
      if(up.ok){if(existed)updated++;else imported++;}
    }
    await rest(`concept2_connections?user_id=eq.${encodeURIComponent(me.id)}`,{
      method:"PATCH",body:JSON.stringify({last_sync_at:new Date().toISOString(),updated_at:new Date().toISOString()})
    });
    return res.json({ok:true,imported,updated,total:results.length});
  }catch(e){
    if(e.message==="AUTH")return res.status(401).json({error:"Sesión de Row Training no válida."});
    console.error(e); return res.status(500).json({error:e.message||"Error interno"});
  }
};
