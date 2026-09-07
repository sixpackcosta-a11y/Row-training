async function rest(url,{method='GET',key,token,body,prefer}={}){
  const response=await fetch(url,{method,headers:{apikey:key,Authorization:`Bearer ${token||key}`,'Content-Type':'application/json',...(prefer?{Prefer:prefer}:{})},body:body===undefined?undefined:JSON.stringify(body)});
  const text=await response.text();
  if(!response.ok)throw new Error(`supabase_${response.status}_${text}`);
  return text?JSON.parse(text):null;
}
function validSourceId(v){return /^[a-z0-9-]{1,120}$/i.test(String(v||''))}
function validSessionId(v){return /^\d+$/.test(String(v||''))}
function validUuid(v){return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(v||''))}

module.exports=async function handler(req,res){
  if(req.method!=='POST')return res.status(405).json({error:'method_not_allowed'});
  const supabaseUrl=process.env.SUPABASE_URL||'https://bnvduwjisqosdjqypnvq.supabase.co';
  const anonKey=process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY||'sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv';
  const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!serviceKey)return res.status(500).json({error:'missing_service_role'});
  try{
    const token=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
    if(!token)return res.status(401).json({error:'missing_token'});
    const auth=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:anonKey,Authorization:`Bearer ${token}`}});
    if(!auth.ok)return res.status(401).json({error:'invalid_token'});
    const user=await auth.json(),kind=String(req.body?.kind||''),sourceId=req.body?.source_id,sessionId=req.body?.training_session_id,targetUserId=req.body?.athlete_user_id||user.id,action=String(req.body?.action||'assign');
    if(!['concept2','workout'].includes(kind)||!validSourceId(sourceId))return res.status(400).json({error:'bad_assignment'});
    if(!validUuid(targetUserId))return res.status(400).json({error:'bad_athlete'});
    if(!['assign','unassign','hide','unhide','splits'].includes(action))return res.status(400).json({error:'bad_action'});
    const selfVisibility=targetUserId===user.id&&(action==='hide'||action==='unhide');
    if(!selfVisibility&&!validSessionId(sessionId))return res.status(400).json({error:'bad_assignment'});

    let session=null;
    if(validSessionId(sessionId)){
      const sessions=await rest(`${supabaseUrl}/rest/v1/training_sessions?id=eq.${sessionId}&select=id,team_code,session_date,session_type,title`,{key:serviceKey});
      session=sessions?.[0];
      if(!session||!['ERG','GYM'].includes(session.session_type))return res.status(404).json({error:'planned_session_not_found'});
      if(targetUserId!==user.id){
        const allowed=await rest(`${supabaseUrl}/rest/v1/rpc/can_edit_team_v72`,{method:'POST',key:anonKey,token,body:{p_team:session.team_code}});
        if(allowed!==true)return res.status(403).json({error:'coach_team_required'});
      }
      const membership=await rest(`${supabaseUrl}/rest/v1/rower_team_memberships?user_id=eq.${targetUserId}&team_code=eq.${encodeURIComponent(session.team_code)}&is_rower=eq.true&select=user_id`,{key:serviceKey});
      let belongs=!!membership?.length;
      if(!belongs){const profile=await rest(`${supabaseUrl}/rest/v1/profiles?user_id=eq.${targetUserId}&team_code=eq.${encodeURIComponent(session.team_code)}&select=user_id`,{key:serviceKey});belongs=!!profile?.length}
      if(!belongs)return res.status(403).json({error:'rower_team_required'});
    }

    // V148 · segunda barrera contra dobles asignaciones del mismo remero.
    // La interfaz ya bloquea estas sesiones, pero la API vuelve a comprobarlo para evitar errores por concurrencia o clientes antiguos.
    if(action==='assign'&&session){
      const duplicate=[];
      const workoutRows=await rest(`${supabaseUrl}/rest/v1/workout_logs?user_id=eq.${targetUserId}&training_session_id=eq.${session.id}&select=id,session_type,hidden`,{key:serviceKey});
      (workoutRows||[]).forEach(r=>{
        const actualType=String(r.session_type||'').toUpperCase().replace('ERGO','ERG');
        if(r.hidden===true||actualType!==session.session_type||(kind==='workout'&&String(r.id)===String(sourceId)))return;
        duplicate.push('workout');
      });
      if(session.session_type==='ERG'){
        const conceptRows=await rest(`${supabaseUrl}/rest/v1/concept2_results?user_id=eq.${targetUserId}&training_session_id=eq.${session.id}&select=id,hidden`,{key:serviceKey});
        (conceptRows||[]).forEach(r=>{if(r.hidden!==true&&!(kind==='concept2'&&String(r.id)===String(sourceId)))duplicate.push('concept2')});
      }
      if(duplicate.length)return res.status(409).json({error:'Esta sesión ya tiene otro resultado asignado para este remero. Quita esa asociación u oculta el registro anterior antes de asignar uno nuevo.'});
    }

    if(kind==='concept2'){
      if(session&&session.session_type!=='ERG')return res.status(400).json({error:'type_mismatch'});
      const rows=await rest(`${supabaseUrl}/rest/v1/concept2_results?id=eq.${sourceId}&user_id=eq.${targetUserId}&select=id,concept2_result_id`,{key:serviceKey});
      if(!rows?.length)return res.status(404).json({error:'result_not_found'});
      if(action==='hide'||action==='unhide')await rest(`${supabaseUrl}/rest/v1/concept2_results?id=eq.${sourceId}&user_id=eq.${targetUserId}`,{method:'PATCH',key:serviceKey,prefer:'return=minimal',body:{hidden:action==='hide',updated_at:new Date().toISOString()}});
      else if(action==='splits'){
        const indexes=[...new Set((Array.isArray(req.body?.excluded_splits)?req.body.excluded_splits:[]).map(Number).filter(x=>Number.isInteger(x)&&x>=0&&x<100))].sort((a,b)=>a-b);
        await rest(`${supabaseUrl}/rest/v1/concept2_results?id=eq.${sourceId}&user_id=eq.${targetUserId}`,{method:'PATCH',key:serviceKey,prefer:'return=minimal',body:{excluded_splits:indexes,updated_at:new Date().toISOString()}});
      }
      else if(action==='unassign')await rest(`${supabaseUrl}/rest/v1/concept2_results?id=eq.${sourceId}&user_id=eq.${targetUserId}`,{method:'PATCH',key:serviceKey,prefer:'return=minimal',body:{training_session_id:null,matched_session_code:null,matched_intent_id:null,match_status:'unplanned',match_confidence:0,updated_at:new Date().toISOString()}});
      else await rest(`${supabaseUrl}/rest/v1/concept2_results?id=eq.${sourceId}&user_id=eq.${targetUserId}`,{method:'PATCH',key:serviceKey,prefer:'return=minimal',body:{training_session_id:Number(session.id),matched_session_code:session.title,match_status:'matched',match_confidence:100,updated_at:new Date().toISOString()}});
    }else{
      const rows=await rest(`${supabaseUrl}/rest/v1/workout_logs?id=eq.${sourceId}&user_id=eq.${targetUserId}&select=id,session_type`,{key:serviceKey});
      const row=rows?.[0],actual=String(row?.session_type||'').toUpperCase().replace('ERGO','ERG');
      if(!row)return res.status(404).json({error:'result_not_found'});
      if(session&&actual!==session.session_type)return res.status(400).json({error:'type_mismatch'});
      if(action==='hide'||action==='unhide')await rest(`${supabaseUrl}/rest/v1/workout_logs?id=eq.${sourceId}&user_id=eq.${targetUserId}`,{method:'PATCH',key:serviceKey,prefer:'return=minimal',body:{hidden:action==='hide'}});
      else if(action==='unassign')await rest(`${supabaseUrl}/rest/v1/workout_logs?id=eq.${sourceId}&user_id=eq.${targetUserId}`,{method:'PATCH',key:serviceKey,prefer:'return=minimal',body:{training_session_id:null}});
      else await rest(`${supabaseUrl}/rest/v1/workout_logs?id=eq.${sourceId}&user_id=eq.${targetUserId}`,{method:'PATCH',key:serviceKey,prefer:'return=minimal',body:{training_session_id:Number(session.id),session_code:session.title,session_date:session.session_date}});
    }
    return res.status(200).json({ok:true,session,action});
  }catch(error){
    console.error(error);return res.status(500).json({error:String(error?.message||error)});
  }
};
