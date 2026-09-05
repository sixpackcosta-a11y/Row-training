const webpush=require('web-push');

async function rest(url,{method='GET',key,body,prefer}={}){
  const r=await fetch(url,{method,headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json',...(prefer?{Prefer:prefer}:{})},body:body===undefined?undefined:JSON.stringify(body)});
  const t=await r.text();
  if(!r.ok)throw new Error(`supabase_${r.status}_${t}`);
  return t?JSON.parse(t):null;
}
function uniq(a){return [...new Set((a||[]).filter(Boolean).map(String))]}
function validUuid(v){return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(v||''))}
function cut(v,n){return String(v||'').trim().slice(0,n)}
function teamInFilter(xs){return xs.map(x=>`"${String(x).replace(/"/g,'')}"`).join(',')}
async function deliverNotifications({supabaseUrl,serviceKey,recipientIds,title,body,url,type,sourceBase}){
  recipientIds=uniq(recipientIds).filter(validUuid);
  if(!recipientIds.length)return {ok:true,recipients:0,push_found:0,push_sent:0,push_failed:0};
  // Comprueba cada clave exacta. app_notifications usa un índice único parcial y
  // no conviene depender ni de UPSERT ni de un filtro LIKE para desduplicar.
  const checks=await Promise.all(recipientIds.map(async uid=>{
    const sourceKey=`${sourceBase}:${uid}`;
    const prior=await rest(`${supabaseUrl}/rest/v1/app_notifications?user_id=eq.${encodeURIComponent(uid)}&source_key=eq.${encodeURIComponent(sourceKey)}&select=id&limit=1`,{key:serviceKey})||[];
    return prior.length?null:uid;
  }));
  const pending=checks.filter(Boolean);
  if(!pending.length)return {ok:true,recipients:recipientIds.length,push_found:0,push_sent:0,push_failed:0,duplicate:true};
  const notifications=pending.map(uid=>({user_id:uid,type,title,body,url,source_key:`${sourceBase}:${uid}`}));
  await rest(`${supabaseUrl}/rest/v1/app_notifications`,{method:'POST',key:serviceKey,body:notifications,prefer:'return=minimal'});
  let pushFound=0,pushSent=0,pushFailed=0;const errors=[];
  const pub=process.env.VAPID_PUBLIC_KEY,priv=process.env.VAPID_PRIVATE_KEY;
  if(pub&&priv){
    webpush.setVapidDetails('https://rowtraining.vercel.app',pub,priv);
    const ids=pending.map(encodeURIComponent).join(',');
    const subs=await rest(`${supabaseUrl}/rest/v1/push_subscriptions?user_id=in.(${ids})&select=id,user_id,endpoint,p256dh,auth`,{key:serviceKey})||[];
    pushFound=subs.length;
    for(const ps of subs){
      try{await webpush.sendNotification({endpoint:ps.endpoint,keys:{p256dh:ps.p256dh,auth:ps.auth}},JSON.stringify({title,body,url,tag:`rowtraining-${type}-${sourceBase}`}));pushSent++}
      catch(e){pushFailed++;errors.push({user_id:ps.user_id,statusCode:e?.statusCode||null,message:String(e?.body||e?.message||e).slice(0,250)});if(e?.statusCode===404||e?.statusCode===410){try{await rest(`${supabaseUrl}/rest/v1/push_subscriptions?id=eq.${ps.id}`,{method:'DELETE',key:serviceKey})}catch(_){}}}
    }
  }
  return {ok:true,recipients:recipientIds.length,push_found:pushFound,push_sent:pushSent,push_failed:pushFailed,errors:errors.slice(0,10)};
}

module.exports=async function handler(req,res){
  if(req.method!=='POST')return res.status(405).json({error:'method_not_allowed'});
  const supabaseUrl=process.env.SUPABASE_URL||'https://bnvduwjisqosdjqypnvq.supabase.co';
  const anonKey=process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY||'sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv';
  const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!serviceKey)return res.status(500).json({error:'missing_service_role'});
  try{
    const token=(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
    if(!token)return res.status(401).json({error:'missing_token'});
    const vr=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:anonKey,Authorization:`Bearer ${token}`}});
    if(!vr.ok)return res.status(401).json({error:'invalid_token'});
    const sender=await vr.json();

    const audience=req.body?.audience||{};
    if(audience.mode==='workout_coaches'){
      const teamCode=cut(audience.team_code,40),sourceType=cut(audience.source_type,30),sourceId=cut(audience.source_id,120);
      if(!/^[a-z0-9_-]{2,40}$/i.test(teamCode)||!sourceId)return res.status(400).json({error:'bad_workout_event'});
      const [membership,profileRows]=await Promise.all([
        rest(`${supabaseUrl}/rest/v1/rower_team_memberships?user_id=eq.${sender.id}&team_code=eq.${encodeURIComponent(teamCode)}&is_rower=eq.true&select=user_id`,{key:serviceKey}),
        rest(`${supabaseUrl}/rest/v1/profiles?user_id=eq.${sender.id}&select=full_name,team_code`,{key:serviceKey})
      ]);
      // Las cuentas anteriores a la tabla multiequipo pueden seguir usando el
      // equipo principal de profiles, igual que hace la app al iniciar sesión.
      const senderProfile=profileRows?.[0]||null;
      if(!membership?.length&&String(senderProfile?.team_code||'')!==teamCode)return res.status(403).json({error:'rower_team_required'});
      let kind='',sessionName='',sessionDate='';
      if(sourceType==='workout'){
        if(!/^\d+$/.test(sourceId))return res.status(400).json({error:'bad_source_id'});
        const rows=await rest(`${supabaseUrl}/rest/v1/workout_logs?id=eq.${encodeURIComponent(sourceId)}&user_id=eq.${sender.id}&select=id,session_type,session_code,session_date`,{key:serviceKey}),row=rows?.[0];
        kind=String(row?.session_type||'').toLowerCase();if(!row||!['gym','ergo'].includes(kind))return res.status(404).json({error:'workout_not_found'});
        sessionName=cut(row.session_code||(kind==='gym'?'GYM':'ERGO'),120);sessionDate=String(row.session_date||'').slice(0,10);
      }else if(sourceType==='concept2'){
        const rows=await rest(`${supabaseUrl}/rest/v1/concept2_results?user_id=eq.${sender.id}&concept2_result_id=eq.${encodeURIComponent(sourceId)}&select=concept2_result_id,workout_date,matched_session_code`,{key:serviceKey}),row=rows?.[0];
        if(!row)return res.status(404).json({error:'concept2_result_not_found'});kind='ergo';sessionName=cut(row.matched_session_code||'ERGO · ErgData',120);sessionDate=String(row.workout_date||'').slice(0,10);
      }else return res.status(400).json({error:'bad_source_type'});
      const [teamStaff,globalCoaches]=await Promise.all([
        rest(`${supabaseUrl}/rest/v1/team_staff_roles?team_code=eq.${encodeURIComponent(teamCode)}&staff_role=eq.coach&select=user_id`,{key:serviceKey}),
        rest(`${supabaseUrl}/rest/v1/user_roles?role=eq.coach&select=user_id`,{key:serviceKey})
      ]);
      const recipientIds=uniq([...(teamStaff||[]).map(x=>x.user_id),...(globalCoaches||[]).map(x=>x.user_id)]);
      const athlete=cut(senderProfile?.full_name||sender.email||'Un remero',100),label=kind==='gym'?'GYM':'ERGO',dateText=sessionDate?sessionDate.split('-').reverse().join('/'):'hoy';
      const title=`${label} registrado`;
      const body=`${athlete} ha registrado ${sessionName} · ${dateText}.`;
      const result=await deliverNotifications({supabaseUrl,serviceKey,recipientIds,title,body,url:`/?tab=result&view=rowers&team=${encodeURIComponent(teamCode)}&athlete=${encodeURIComponent(sender.id)}`,type:'workout_registered',sourceBase:`workout_registered:${sourceType}:${sourceId}:${teamCode}`});
      return res.status(200).json(result);
    }

    const [globalRows,staffRows]=await Promise.all([
      rest(`${supabaseUrl}/rest/v1/user_roles?user_id=eq.${sender.id}&role=eq.coach&select=user_id`,{key:serviceKey}),
      rest(`${supabaseUrl}/rest/v1/team_staff_roles?user_id=eq.${sender.id}&staff_role=eq.coach&select=team_code`,{key:serviceKey})
    ]);
    const isGlobal=Array.isArray(globalRows)&&globalRows.length>0;
    const allowedTeams=uniq((staffRows||[]).map(x=>x.team_code));
    if(!isGlobal&&!allowedTeams.length)return res.status(403).json({error:'coach_required'});

    const title=cut(req.body?.title,120),body=cut(req.body?.body,500),url=cut(req.body?.url||'/',300)||'/',type=cut(req.body?.type||'coach_message',50)||'coach_message';
    if(!title||!body)return res.status(400).json({error:'title_and_body_required'});
    const mode=audience.mode;
    let requestedTeams=uniq(audience.team_codes).filter(x=>/^[a-z0-9_-]{2,40}$/i.test(x));
    if(!isGlobal)requestedTeams=requestedTeams.filter(x=>allowedTeams.includes(x));
    if((mode==='teams'||mode==='users')&&!requestedTeams.length&&!isGlobal)return res.status(403).json({error:'team_not_allowed'});

    let recipientIds=[];
    if(mode==='teams'){
      if(!requestedTeams.length)return res.status(400).json({error:'no_teams'});
      const teamExpr=requestedTeams.map(encodeURIComponent).join(',');
      const rows=await rest(`${supabaseUrl}/rest/v1/rower_team_memberships?team_code=in.(${teamExpr})&is_rower=eq.true&select=user_id,team_code`,{key:serviceKey});
      recipientIds=uniq((rows||[]).map(x=>x.user_id));
    }else if(mode==='users'){
      const wanted=uniq(audience.user_ids).filter(validUuid);
      if(!wanted.length)return res.status(400).json({error:'no_users'});
      // Un entrenador solo puede enviar a remeros de sus equipos. Global coach puede enviar a cualquier remero.
      if(isGlobal){
        const ids=wanted.map(encodeURIComponent).join(',');
        const rows=await rest(`${supabaseUrl}/rest/v1/rower_team_memberships?user_id=in.(${ids})&is_rower=eq.true&select=user_id,team_code`,{key:serviceKey});
        recipientIds=uniq((rows||[]).map(x=>x.user_id)).filter(x=>wanted.includes(x));
      }else{
        const ids=wanted.map(encodeURIComponent).join(','),teams=allowedTeams.map(encodeURIComponent).join(',');
        const rows=await rest(`${supabaseUrl}/rest/v1/rower_team_memberships?user_id=in.(${ids})&team_code=in.(${teams})&is_rower=eq.true&select=user_id,team_code`,{key:serviceKey});
        recipientIds=uniq((rows||[]).map(x=>x.user_id)).filter(x=>wanted.includes(x));
      }
    }else return res.status(400).json({error:'bad_audience'});

    recipientIds=recipientIds.filter(uid=>uid!==sender.id);
    if(!recipientIds.length)return res.status(200).json({ok:true,recipients:0,push_found:0,push_sent:0,push_failed:0});

    const result=await deliverNotifications({supabaseUrl,serviceKey,recipientIds,title,body,url,type,sourceBase:`${type}:${sender.id}:${Date.now()}`});
    return res.status(200).json(result);
  }catch(e){return res.status(500).json({error:e?.message||String(e)});}
};
