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
function norm(v){return String(v||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/×/g,'x').replace(/\s+/g,' ').trim()}
function addDays(dateStr,days){const d=new Date(`${dateStr}T12:00:00Z`);d.setUTCDate(d.getUTCDate()+days);return d.toISOString().slice(0,10)}
function planWorkText(title,content){
  const lines=String(content||'').split(/\n+/).map(x=>x.trim()).filter(Boolean);
  const work=lines.find(x=>/^TRABAJO\b/i.test(x));
  return `${title||''}\n${work||''}`.trim();
}
function planSignature(title,content){
  const t=planWorkText(title,content);
  let m=t.match(/(\d+)\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*(?:min(?:uto)?s?|')\b/i);
  const spm=Number(((t.match(/@\s*(\d{2})\b/i)||t.match(/\b(\d{2})\s*ppm\b/i))||[])[1]||0)||null;
  if(m){const reps=Number(m[1]),eachSec=Number(String(m[2]).replace(',','.'))*60;return {kind:'time_intervals',reps,eachSec,totalSec:reps*eachSec,spm};}
  m=t.match(/(\d+)\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*m\b/i);
  if(m){const reps=Number(m[1]),eachM=Number(String(m[2]).replace(',','.'));return {kind:'distance_intervals',reps,eachM,totalM:reps*eachM,spm};}
  const workLine=String(content||'').split(/\n+/).map(x=>x.trim()).find(x=>/^TRABAJO\b/i.test(x))||'';
  m=workLine.match(/(\d+(?:[.,]\d+)?)\s*min\b/i);
  if(m)return {kind:'time',totalSec:Number(String(m[1]).replace(',','.'))*60,spm};
  m=workLine.match(/(\d+(?:[.,]\d+)?)\s*m\b/i);
  if(m)return {kind:'distance',totalM:Number(String(m[1]).replace(',','.')),spm};
  return {kind:'unknown',spm};
}
function resultParts(result){
  const w=result?.workout||{};
  const parts=w.intervals||w.splits||result?.intervals||result?.splits||[];
  return Array.isArray(parts)?parts.filter(p=>p&&Number(p.time||0)>0&&Number(p.distance||0)>=0):[];
}
function median(nums){const a=nums.filter(Number.isFinite).sort((x,y)=>x-y);if(!a.length)return null;const n=a.length;return n%2?a[(n-1)/2]:(a[n/2-1]+a[n/2])/2}
function resultSignature(result){
  const parts=resultParts(result);
  const times=parts.map(p=>p.time==null?NaN:Number(p.time)/10).filter(Number.isFinite);
  const dists=parts.map(p=>p.distance==null?NaN:Number(p.distance)).filter(Number.isFinite);
  return {
    totalSec:resultSeconds(result),totalM:result.distance==null?null:Number(result.distance),
    reps:parts.length||null,eachSec:median(times),eachM:median(dists),
    spm:result.stroke_rate==null?null:Number(result.stroke_rate),
    workoutType:norm(result.workout_type||'')
  };
}
function relDiff(a,b){return a&&b?Math.abs(a-b)/Math.abs(b):Infinity}
function compatibility(result,intent){
  const ps=intent.signature||{kind:'unknown'},rs=resultSignature(result);
  let score=0,exact=false;
  if(ps.kind==='time_intervals'){
    if(rs.reps!=null){
      if(rs.reps!==ps.reps||!rs.eachSec||relDiff(rs.eachSec,ps.eachSec)>.08)return null;
      score=75;exact=true;
    }else{
      if(!rs.totalSec||relDiff(rs.totalSec,ps.totalSec)>.05||!/interval|split/.test(rs.workoutType))return null;
      score=60;
    }
  }else if(ps.kind==='distance_intervals'){
    if(rs.reps!=null){
      if(rs.reps!==ps.reps||!rs.eachM||relDiff(rs.eachM,ps.eachM)>.08)return null;
      score=75;exact=true;
    }else{
      if(!rs.totalM||relDiff(rs.totalM,ps.totalM)>.05||!/interval|split/.test(rs.workoutType))return null;
      score=60;
    }
  }else if(ps.kind==='time'){
    if(!rs.totalSec||relDiff(rs.totalSec,ps.totalSec)>.06)return null;
    score=65;exact=true;
  }else if(ps.kind==='distance'){
    if(!rs.totalM||relDiff(rs.totalM,ps.totalM)>.06)return null;
    score=65;exact=true;
  }else{
    // Sin una prescripción cuantificable no se autoasigna. La fecha por sí sola nunca basta.
    return null;
  }
  if(ps.spm&&rs.spm){const diff=Math.abs(ps.spm-rs.spm);if(diff<=1)score+=10;else if(diff<=3)score+=5;}
  const sameDate=dateOnly(result.date||result.date_utc)===intent.scheduled_date;
  if(sameDate)score+=20;
  else if(intent.scheduled_date&&dateOnly(result.date||result.date_utc)>intent.scheduled_date)score+=5;
  return {score,exact,sameDate};
}
function scoreResult(result,intents){
  const hits=[];
  for(const i of intents){const c=compatibility(result,i);if(c)hits.push({intent:i,...c});}
  hits.sort((a,b)=>b.score-a.score);
  const best=hits[0];
  if(!best)return {status:'unplanned',confidence:0,code:null,intentId:null,sessionId:null};
  const second=hits.find(x=>String(x.intent.training_session_id||'')!==String(best.intent.training_session_id||''));
  // Si hay dos sesiones diferentes con la misma prescripción y puntuación parecida, no elegimos por la cara.
  if(second&&second.score>=best.score-5){
    return {status:'review',confidence:Math.min(best.score,99),code:best.intent.session_code,intentId:best.intent.id||null,sessionId:null};
  }
  if(best.score>=70){
    return {status:'matched',confidence:Math.min(best.score,100),code:best.intent.session_code,intentId:best.intent.id||null,sessionId:best.intent.training_session_id||null};
  }
  return {status:'review',confidence:Math.min(best.score,99),code:best.intent.session_code,intentId:best.intent.id||null,sessionId:null};
}
async function plannedErgoIntents(userId,results){
  const mr=await rest(`rower_team_memberships?user_id=eq.${encodeURIComponent(userId)}&is_rower=eq.true&select=team_code`);
  if(!mr.ok)return [];
  const teams=[...new Set((await mr.json()).map(x=>x.team_code).filter(Boolean))];
  const dates=results.map(x=>dateOnly(x.date||x.date_utc)).filter(Boolean).sort();
  if(!teams.length||!dates.length)return [];
  const teamFilter=teams.map(encodeURIComponent).join(',');
  // Miramos también unas semanas hacia atrás: permite recuperar un 2x10 pendiente hecho días después,
  // pero solo si la prescripción coincide; la fecha nunca decide por sí sola.
  const from=addDays(dates[0],-35),to=dates[dates.length-1];
  const sr=await rest(`training_sessions?team_code=in.(${teamFilter})&session_type=eq.ERG&session_date=gte.${encodeURIComponent(from)}&session_date=lte.${encodeURIComponent(to)}&select=id,team_code,session_date,title,content`);
  if(!sr.ok)return [];
  return (await sr.json()).map(x=>({
    id:null,training_session_id:x.id,scheduled_date:x.session_date,session_code:x.title||'ERGO',session_name:x.title||'ERGO',
    expected_distance_m:null,expected_duration_seconds:null,expected_spm:null,expected_workout_type:null,
    signature:planSignature(x.title,x.content),from_planning:true
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
    const savedIntents=(ir.ok?await ir.json():[]).map(i=>({...i,signature:planSignature(i.session_name||i.session_code||'',i.content||'')}));
    const planningIntents=await plannedErgoIntents(me.id,results).catch(()=>[]);
    const seenPlans=new Set();
    const intents=[...savedIntents,...planningIntents].filter(i=>{
      const key=i.training_session_id?`plan:${i.training_session_id}`:`intent:${i.id||''}:${i.scheduled_date||''}:${i.session_code||''}`;
      if(seenPlans.has(key))return false;seenPlans.add(key);return true;
    });

    // Una única consulta para saber cuáles ya existían.
    const idList=results.map(x=>String(x.id)).filter(Boolean);
    let existing=new Set(),existingRows=new Map();
    if(idList.length){
      const er=await rest(`concept2_results?user_id=eq.${encodeURIComponent(me.id)}&concept2_result_id=in.(${idList.map(x=>encodeURIComponent(x)).join(",")})&select=concept2_result_id,training_session_id,matched_intent_id,matched_session_code,match_status,match_confidence`);
      if(er.ok){
        const old=await er.json();
        existing=new Set(old.map(x=>String(x.concept2_result_id)));
        existingRows=new Map(old.map(x=>[String(x.concept2_result_id),x]));
      }
    }

    const now=new Date().toISOString();
    const rows=results.map(x=>{
      const old=existingRows.get(String(x.id));
      let match;
      if(old?.training_session_id){
        // Una asignación explícita/manual ya guardada manda siempre. La sincronización no la toca.
        match={status:old.match_status||'matched',confidence:old.match_confidence??100,code:old.matched_session_code||null,intentId:old.matched_intent_id||null,sessionId:old.training_session_id};
      }else if(old?.match_status==='unplanned'&&old?.matched_session_code==null){
        // Si el entrenador/remero lo dejó expresamente sin asignar, no lo reasignamos en una sincronización posterior.
        match={status:'unplanned',confidence:old.match_confidence??0,code:null,intentId:null,sessionId:null};
      }else{
        match=scoreResult(x,intents);
      }
      return {
        user_id:me.id,concept2_result_id:String(x.id),workout_date:x.date||x.date_utc,
        distance_m:x.distance==null?null:Number(x.distance),
        time_tenths:x.time==null?null:Number(x.time),time_formatted:x.time_formatted||null,
        pace_500_seconds:pace500(x.time,x.distance),spm:x.stroke_rate==null?null:Number(x.stroke_rate),
        avg_hr:x.heart_rate?.average??null,max_hr:x.heart_rate?.max??null,
        workout_type:x.workout_type||null,source:x.source||null,
        training_session_id:match.sessionId||null,
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
