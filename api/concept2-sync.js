const SUPABASE_URL="https://bnvduwjisqosdjqypnvq.supabase.co";
const SUPABASE_ANON="sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv";
const C2_CLIENT_ID="bx8m9j1Qj8GZnN3ni8Wz5QEb15SHB9amysaSgelu";
const C2_SCOPE="user:read,results:read";

async function fetchTimed(url,opts={},ms=15000){
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),ms);
  try{return await fetch(url,{...opts,signal:controller.signal});}
  finally{clearTimeout(timer);}
}
async function authUser(req){
  const auth=req.headers.authorization||"";
  if(!auth.startsWith("Bearer ")) throw new Error("AUTH");
  const r=await fetchTimed(`${SUPABASE_URL}/auth/v1/user`,{headers:{apikey:SUPABASE_ANON,Authorization:auth}},10000);
  if(!r.ok) throw new Error("AUTH");
  return r.json();
}
async function rest(path,opts={}){
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!key) throw new Error("Falta SUPABASE_SERVICE_ROLE_KEY en Vercel.");
  return fetchTimed(`${SUPABASE_URL}/rest/v1/${path}`,{
    ...opts,
    headers:{apikey:key,Authorization:`Bearer ${key}`,"Content-Type":"application/json",...(opts.headers||{})}
  },15000);
}
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
  const body=new URLSearchParams({client_id:C2_CLIENT_ID,client_secret:secret,grant_type:"refresh_token",refresh_token:c.refresh_token,scope:C2_SCOPE});
  const r=await fetchTimed("https://log.concept2.com/oauth/access_token",{
    method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded","Accept":"application/json"},body
  },12000);
  const j=await r.json().catch(()=>({}));
  if(!r.ok)throw new Error(j.error_description||"Hay que volver a conectar Concept2.");
  const expiresAt=new Date(Date.now()+(Number(j.expires_in)||604800)*1000).toISOString();
  await rest(`concept2_connections?user_id=eq.${encodeURIComponent(c.user_id)}`,{
    method:"PATCH",body:JSON.stringify({access_token:j.access_token,refresh_token:j.refresh_token||c.refresh_token,expires_at:expiresAt,updated_at:new Date().toISOString()})
  });
  return j.access_token;
}
function dateOnly(v){return String(v||"").slice(0,10)}
function resultSeconds(result){return result.time==null?null:Number(result.time)/10}
function scoreResult(result,intents){
  let best=null;
  for(const i of intents){
    let score=0;
    if(dateOnly(result.date||result.date_utc)===i.scheduled_date)score+=i.from_planning?85:45;
    const d=Number(result.distance||0);
    if(i.expected_distance_m&&d){const diff=Math.abs(d-i.expected_distance_m)/i.expected_distance_m;if(diff<=.03)score+=25;else if(diff<=.10)score+=15;}
    const secs=resultSeconds(result);
    if(i.expected_duration_seconds&&secs){const diff=Math.abs(secs-i.expected_duration_seconds)/i.expected_duration_seconds;if(diff<=.02)score+=25;else if(diff<=.08)score+=15;else if(diff<=.15)score+=8;}
    const spm=Number(result.stroke_rate||0);
    if(i.expected_spm&&spm){const diff=Math.abs(spm-i.expected_spm);if(diff<=1)score+=15;else if(diff<=3)score+=8;}
    if(i.expected_workout_type&&String(result.workout_type||"").toLowerCase().includes(String(i.expected_workout_type).toLowerCase()))score+=15;
    if(!best||score>best.score)best={intent:i,score};
  }
  if(!best||best.score<60)return {status:"unplanned",confidence:Math.min(best?.score||0,100),code:null,intentId:null};
  if(best.score>=80)return {status:"matched",confidence:Math.min(best.score,100),code:best.intent.session_code,intentId:best.intent.id};
  return {status:"review",confidence:Math.min(best.score,100),code:best.intent.session_code,intentId:best.intent.id};
}
async function plannedErgoIntents(userId,results){
  const mr=await rest(`rower_team_memberships?user_id=eq.${encodeURIComponent(userId)}&is_rower=eq.true&select=team_code`);
  if(!mr.ok)return [];
  const teams=[...new Set((await mr.json()).map(x=>x.team_code).filter(Boolean))];
  const dates=results.map(x=>dateOnly(x.date||x.date_utc)).filter(Boolean).sort();
  if(!teams.length||!dates.length)return [];
  const teamFilter=teams.map(encodeURIComponent).join(',');
  const sr=await rest(`training_sessions?team_code=in.(${teamFilter})&session_type=eq.ERG&session_date=gte.${encodeURIComponent(dates[0])}&session_date=lte.${encodeURIComponent(dates[dates.length-1])}&select=id,team_code,session_date,title,content`);
  if(!sr.ok)return [];
  return (await sr.json()).map(x=>({
    id:null,scheduled_date:x.session_date,session_code:x.title||'ERGO',session_name:x.title||'ERGO',
    expected_distance_m:null,expected_duration_seconds:null,expected_spm:null,expected_workout_type:null,
    from_planning:true
  }));
}
async function enrichIntervalDetails(results,token){
  const detailed=[];
  const candidates=results.filter(x=>/(interval|splits)/i.test(String(x.workout_type||''))).slice(0,20);
  const byId=new Map(results.map(x=>[String(x.id),x]));
  for(let i=0;i<candidates.length;i+=5){
    const batch=await Promise.all(candidates.slice(i,i+5).map(async x=>{
      try{
        const r=await fetchTimed(`https://log.concept2.com/api/users/me/results/${encodeURIComponent(x.id)}`,{headers:{Authorization:`Bearer ${token}`,Accept:"application/vnd.c2logbook.v1+json"}},10000);
        if(!r.ok)return x;
        const j=await r.json().catch(()=>({})); return j.data||x;
      }catch(e){return x;}
    }));
    detailed.push(...batch);
  }
  detailed.forEach(x=>byId.set(String(x.id),x));
  return results.map(x=>byId.get(String(x.id))||x);
}
module.exports=async function handler(req,res){
  try{
    const me=await authUser(req);
    const c=await connection(me.id);
    if(req.method==="GET")return res.json({connected:!!c,username:c?.concept2_username||null,last_sync_at:c?.last_sync_at||null});
    if(req.method!=="POST")return res.status(405).json({error:"Método no permitido"});
    if(!c)return res.status(409).json({error:"Primero conecta tu cuenta Concept2."});

    const token=await validToken(c);
    // 50 resultados siguen siendo manejables: el cambio clave es procesarlos en lote,
    // no hacer 2 peticiones a Supabase por cada entrenamiento.
    const limit=Math.min(Math.max(Number(req.body?.limit)||50,1),50);
    const rr=await fetchTimed(`https://log.concept2.com/api/users/me/results?type=rower&number=${limit}`,{
      headers:{Authorization:`Bearer ${token}`,Accept:"application/vnd.c2logbook.v1+json"}
    },15000);
    const rj=await rr.json().catch(()=>({}));
    if(!rr.ok)return res.status(rr.status).json({error:rj.message||"No se pudieron leer resultados de Concept2."});
    let results=Array.isArray(rj)?rj:(rj.data||[]);
    if(!results.length){
      const now=new Date().toISOString();
      await rest(`concept2_connections?user_id=eq.${encodeURIComponent(me.id)}`,{method:"PATCH",body:JSON.stringify({last_sync_at:now,updated_at:now})});
      return res.json({ok:true,imported:0,updated:0,total:0});
    }

    results=await enrichIntervalDetails(results,token);
    const ir=await rest(`ergo_intents?user_id=eq.${encodeURIComponent(me.id)}&select=*&order=scheduled_date.desc`);
    const savedIntents=ir.ok?await ir.json():[];
    const planningIntents=await plannedErgoIntents(me.id,results).catch(()=>[]);
    const intents=[...savedIntents,...planningIntents];

    // Una única consulta para saber cuáles ya existían.
    const idList=results.map(x=>String(x.id)).filter(Boolean);
    let existing=new Set();
    if(idList.length){
      const er=await rest(`concept2_results?user_id=eq.${encodeURIComponent(me.id)}&concept2_result_id=in.(${idList.map(x=>encodeURIComponent(x)).join(",")})&select=concept2_result_id`);
      if(er.ok) existing=new Set((await er.json()).map(x=>String(x.concept2_result_id)));
    }

    const now=new Date().toISOString();
    const rows=results.map(x=>{
      const match=scoreResult(x,intents);
      return {
        user_id:me.id,concept2_result_id:String(x.id),workout_date:x.date||x.date_utc,
        distance_m:x.distance==null?null:Number(x.distance),
        time_tenths:x.time==null?null:Number(x.time),time_formatted:x.time_formatted||null,
        pace_500_seconds:pace500(x.time,x.distance),spm:x.stroke_rate==null?null:Number(x.stroke_rate),
        avg_hr:x.heart_rate?.average??null,max_hr:x.heart_rate?.max??null,
        workout_type:x.workout_type||null,source:x.source||null,
        matched_intent_id:match.intentId,matched_session_code:match.code,
        match_status:match.status,match_confidence:match.confidence,
        raw_result:x,updated_at:now
      };
    });

    // Un único UPSERT para toda la tanda. Evita el bloqueo que producía el bucle anterior.
    const up=await rest("concept2_results?on_conflict=user_id,concept2_result_id",{
      method:"POST",headers:{Prefer:"resolution=merge-duplicates,return=minimal"},body:JSON.stringify(rows)
    });
    if(!up.ok){const txt=await up.text().catch(()=>"");throw new Error(txt||"No se pudieron guardar los resultados Concept2.");}

    await rest(`concept2_connections?user_id=eq.${encodeURIComponent(me.id)}`,{
      method:"PATCH",body:JSON.stringify({last_sync_at:now,updated_at:now})
    });
    const imported=rows.filter(x=>!existing.has(String(x.concept2_result_id))).length;
    const updated=rows.length-imported;
    return res.json({ok:true,imported,updated,total:rows.length});
  }catch(e){
    if(e.message==="AUTH")return res.status(401).json({error:"Sesión de Row Training no válida."});
    if(e?.name==="AbortError")return res.status(504).json({error:"La sincronización está tardando demasiado. Inténtalo de nuevo."});
    console.error(e);return res.status(500).json({error:e.message||"Error interno"});
  }
};
