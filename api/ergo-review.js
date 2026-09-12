const SUPABASE_URL="https://bnvduwjisqosdjqypnvq.supabase.co";
const SUPABASE_ANON="sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv";
async function fetchTimed(url,opts={},ms=12000){const c=new AbortController(),t=setTimeout(()=>c.abort(),ms);try{return await fetch(url,{...opts,signal:c.signal})}finally{clearTimeout(t)}}
async function authUser(req){const a=req.headers.authorization||'';if(!a.startsWith('Bearer '))throw new Error('AUTH');const r=await fetchTimed(`${SUPABASE_URL}/auth/v1/user`,{headers:{apikey:SUPABASE_ANON,Authorization:a}});if(!r.ok)throw new Error('AUTH');return r.json()}
async function rest(path,opts={}){const k=process.env.SUPABASE_SERVICE_ROLE_KEY;if(!k)throw new Error('Falta SUPABASE_SERVICE_ROLE_KEY en Vercel.');return fetchTimed(`${SUPABASE_URL}/rest/v1/${path}`,{...opts,headers:{apikey:k,Authorization:`Bearer ${k}`,'Content-Type':'application/json',...(opts.headers||{})}})}
async function one(path){const r=await rest(path);if(!r.ok)throw new Error(await r.text().catch(()=>''));const a=await r.json();return a[0]||null}
async function canCoach(userId,team){const ur=await one(`user_roles?user_id=eq.${encodeURIComponent(userId)}&select=role`);if(ur?.role==='coach')return true;const tr=await one(`team_staff_roles?user_id=eq.${encodeURIComponent(userId)}&team_code=eq.${encodeURIComponent(team)}&staff_role=eq.coach&select=user_id`);return !!tr}
module.exports=async function handler(req,res){
  try{
    if(req.method!=='POST')return res.status(405).json({error:'Método no permitido'});
    const me=await authUser(req),b=req.body||{},action=String(b.action||'');
    if(!['validate','unvalidate'].includes(action))return res.status(400).json({error:'Acción no válida.'});
    const resultId=String(b.result_id||''),athlete=String(b.athlete_user_id||''),sessionId=String(b.training_session_id||'');
    if(!resultId||!athlete||!sessionId)return res.status(400).json({error:'Faltan datos de la validación.'});
    const result=await one(`concept2_results?id=eq.${encodeURIComponent(resultId)}&user_id=eq.${encodeURIComponent(athlete)}&select=id,user_id,training_session_id,match_status`);
    if(!result)return res.status(404).json({error:'No se encontró el resultado de ErgData.'});
    if(String(result.training_session_id||'')!==sessionId)return res.status(409).json({error:'La asignación ha cambiado. Recarga la semana antes de validar.'});
    const plan=await one(`training_sessions?id=eq.${encodeURIComponent(sessionId)}&select=id,team_code,title`);
    if(!plan)return res.status(404).json({error:'No se encontró la sesión planificada.'});
    if(!(await canCoach(me.id,plan.team_code)))return res.status(403).json({error:'No tienes permiso para validar resultados de este equipo.'});
    const patch=action==='validate'?{match_status:'validated',match_confidence:100,updated_at:new Date().toISOString()}:{match_status:'matched',match_confidence:100,updated_at:new Date().toISOString()};
    const up=await rest(`concept2_results?id=eq.${encodeURIComponent(resultId)}&user_id=eq.${encodeURIComponent(athlete)}`,{method:'PATCH',headers:{Prefer:'return=minimal'},body:JSON.stringify(patch)});
    if(!up.ok)throw new Error((await up.text().catch(()=>''))||'No se pudo guardar la validación.');
    return res.json({ok:true,validated:action==='validate'});
  }catch(e){if(e.message==='AUTH')return res.status(401).json({error:'Sesión no válida.'});console.error(e);return res.status(500).json({error:e.message||'Error interno'})}
};
