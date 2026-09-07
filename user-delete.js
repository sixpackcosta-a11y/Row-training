const SUPABASE_URL=process.env.SUPABASE_URL||'https://bnvduwjisqosdjqypnvq.supabase.co';
const PUBLIC_KEY=process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY||'sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv';
const SERVICE_KEY=process.env.SUPABASE_SERVICE_ROLE_KEY;

function uuid(v){return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(v||''));}
async function jfetch(url,opts={}){
  const r=await fetch(url,opts);const txt=await r.text();let body=null;try{body=txt?JSON.parse(txt):null}catch{body=txt}
  return {ok:r.ok,status:r.status,body};
}
async function rest(path,{method='GET',body,prefer='return=minimal'}={}){
  const r=await jfetch(`${SUPABASE_URL}/rest/v1/${path}`,{method,headers:{apikey:SERVICE_KEY,Authorization:`Bearer ${SERVICE_KEY}`,'Content-Type':'application/json',Prefer:prefer},body:body===undefined?undefined:JSON.stringify(body)});
  if(!r.ok)throw new Error(`supabase_${r.status}: ${typeof r.body==='string'?r.body:JSON.stringify(r.body)}`);return r.body;
}
module.exports=async function handler(req,res){
  if(req.method!=='POST')return res.status(405).json({error:'method_not_allowed'});
  if(!SERVICE_KEY)return res.status(500).json({error:'missing_service_role'});
  try{
    const token=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
    if(!token)return res.status(401).json({error:'missing_session'});
    const meR=await jfetch(`${SUPABASE_URL}/auth/v1/user`,{headers:{apikey:PUBLIC_KEY,Authorization:`Bearer ${token}`}});
    if(!meR.ok||!meR.body?.id)return res.status(401).json({error:'invalid_session'});
    const me=meR.body;
    const roles=await rest(`user_roles?user_id=eq.${encodeURIComponent(me.id)}&role=eq.coach&select=user_id`);
    if(!Array.isArray(roles)||!roles.length)return res.status(403).json({error:'admin_required'});
    const body=typeof req.body==='string'?JSON.parse(req.body||'{}'):(req.body||{}),target=String(body.user_id||'');
    if(!uuid(target))return res.status(400).json({error:'invalid_user_id'});
    if(target===me.id)return res.status(400).json({error:'cannot_delete_self'});

    // Primero elimina la cuenta Auth. Si alguna FK lo impide, no seguimos borrando datos a medias.
    const authDel=await jfetch(`${SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(target)}`,{method:'DELETE',headers:{apikey:SERVICE_KEY,Authorization:`Bearer ${SERVICE_KEY}`}});
    if(!authDel.ok)return res.status(authDel.status||500).json({error:'auth_delete_failed',detail:authDel.body});

    // Limpieza de tablas que pueden no tener FK/cascade a auth.users.
    const cleanup=[
      ['push_subscriptions','user_id'],['app_notifications','user_id'],['concept2_results','user_id'],['concept2_connections','user_id'],['ergo_intents','user_id'],
      ['gym_exercise_results','user_id'],['ergo_results','user_id'],['workout_logs','user_id'],['athlete_metrics','user_id'],
      ['rower_team_memberships','user_id'],['team_staff_roles','user_id'],['registration_requests','user_id'],['user_roles','user_id'],['profiles','user_id']
    ];
    const warnings=[];
    for(const [table,col] of cleanup){
      try{await rest(`${table}?${col}=eq.${encodeURIComponent(target)}`,{method:'DELETE'});}catch(e){warnings.push(`${table}: ${e.message}`)}
    }
    return res.status(200).json({ok:true,warnings});
  }catch(e){return res.status(500).json({error:'delete_failed',detail:e?.message||String(e)});}
};
