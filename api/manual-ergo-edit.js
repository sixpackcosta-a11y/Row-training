async function rest(url,{method='GET',key,token,body,prefer}={}){
  const response=await fetch(url,{method,headers:{apikey:key,Authorization:`Bearer ${token||key}`,'Content-Type':'application/json',...(prefer?{Prefer:prefer}:{})},body:body===undefined?undefined:JSON.stringify(body)});
  const text=await response.text();
  if(!response.ok)throw new Error(`supabase_${response.status}_${text}`);
  return text?JSON.parse(text):null;
}
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
    const user=await auth.json();
    const ergoResultId=String(req.body?.ergo_result_id??'').trim();
    const targetUserId=String(req.body?.athlete_user_id||user.id);
    if(!ergoResultId||ergoResultId.length>180)return res.status(400).json({error:'bad_ergo_result_id'});
    if(!validUuid(targetUserId))return res.status(400).json({error:'bad_athlete'});
    if(targetUserId!==user.id){
      const teamCode=String(req.body?.team_code||'');
      if(!/^[a-z0-9_-]{1,80}$/i.test(teamCode))return res.status(400).json({error:'team_required'});
      const allowed=await rest(`${supabaseUrl}/rest/v1/rpc/can_edit_team_v72`,{method:'POST',key:anonKey,token,body:{p_team:teamCode}});
      if(allowed!==true)return res.status(403).json({error:'coach_team_required'});
    }
    const rows=await rest(`${supabaseUrl}/rest/v1/ergo_results?id=eq.${encodeURIComponent(ergoResultId)}&user_id=eq.${encodeURIComponent(targetUserId)}&select=id,workout_id`,{key:serviceKey});
    const row=rows?.[0];
    if(!row)return res.status(404).json({error:'manual_ergo_not_found'});
    const m=req.body?.manual||{},num=v=>v===null||v===undefined||v===''?null:Number(v);
    const clean={distance_m:num(m.distance_m),time_seconds:num(m.time_seconds),pace_500_seconds:num(m.pace_500_seconds),spm:num(m.spm),avg_hr:num(m.avg_hr),max_hr:num(m.max_hr),notes:m.notes==null?null:String(m.notes).slice(0,2000),splits:Array.isArray(m.splits)?m.splits.slice(0,30):[]};
    for(const k of ['distance_m','time_seconds','pace_500_seconds','spm','avg_hr','max_hr'])if(clean[k]!==null&&!Number.isFinite(clean[k]))return res.status(400).json({error:'bad_manual_value',field:k});
    await rest(`${supabaseUrl}/rest/v1/ergo_results?id=eq.${encodeURIComponent(ergoResultId)}&user_id=eq.${encodeURIComponent(targetUserId)}`,{method:'PATCH',key:serviceKey,prefer:'return=minimal',body:clean});
    if(row.workout_id){try{await rest(`${supabaseUrl}/rest/v1/workout_logs?id=eq.${encodeURIComponent(row.workout_id)}&user_id=eq.${encodeURIComponent(targetUserId)}`,{method:'PATCH',key:serviceKey,prefer:'return=minimal',body:{notes:clean.notes}})}catch(_){} }
    return res.status(200).json({ok:true,ergo_result_id:ergoResultId,workout_id:row.workout_id||null});
  }catch(e){return res.status(500).json({error:'manual_edit_failed',detail:String(e?.message||e).slice(0,1200)})}
};
