const webpush=require('web-push');
const SUPABASE_URL=process.env.SUPABASE_URL||'https://bnvduwjisqosdjqypnvq.supabase.co';
const SUPABASE_ANON=process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY||'sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv';

// V890 · prueba de envío: manda un aviso de prueba a TODOS los dispositivos registrados de quien la pide
// (así se ve si el servidor puede entregar al móvil). Devuelve cuántos dispositivos hay, cuántos se enviaron y los fallos.
module.exports=async function handler(req,res){
  if(req.method!=='POST')return res.status(405).json({error:'method_not_allowed'});
  const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY,pub=process.env.VAPID_PUBLIC_KEY,priv=process.env.VAPID_PRIVATE_KEY;
  if(!serviceKey)return res.status(500).json({error:'missing_service_role'});
  if(!pub||!priv)return res.status(200).json({error:'push_not_configured'});
  try{
    const token=(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
    if(!token)return res.status(401).json({error:'missing_token'});
    const vr=await fetch(`${SUPABASE_URL}/auth/v1/user`,{headers:{apikey:SUPABASE_ANON,Authorization:`Bearer ${token}`}});
    if(!vr.ok)return res.status(401).json({error:'invalid_token'});
    const user=await vr.json();
    const q=await fetch(`${SUPABASE_URL}/rest/v1/push_subscriptions?user_id=eq.${encodeURIComponent(user.id)}&select=id,endpoint,p256dh,auth`,{headers:{apikey:serviceKey,Authorization:`Bearer ${serviceKey}`}});
    if(!q.ok)return res.status(500).json({error:'supabase_'+q.status});
    const subs=await q.json();
    webpush.setVapidDetails('https://rowtraining.vercel.app',pub,priv);
    let sent=0;const errors=[];
    await Promise.all(subs.map(async ps=>{
      try{
        await webpush.sendNotification({endpoint:ps.endpoint,keys:{p256dh:ps.p256dh,auth:ps.auth}},JSON.stringify({title:'🔔 Prueba de Row Training',body:'Si ves este aviso, las notificaciones funcionan en este dispositivo.',url:'/',tag:'rowtraining-test'}),{TTL:600,urgency:'high',timeout:8000});
        sent++;
      }catch(e){
        errors.push({statusCode:e?.statusCode||null,message:String(e?.body||e?.message||e).slice(0,200)});
        if(e?.statusCode===404||e?.statusCode===410){try{await fetch(`${SUPABASE_URL}/rest/v1/push_subscriptions?id=eq.${ps.id}`,{method:'DELETE',headers:{apikey:serviceKey,Authorization:`Bearer ${serviceKey}`}})}catch(_){}}
      }
    }));
    return res.status(200).json({ok:true,found:subs.length,sent,errors});
  }catch(e){return res.status(500).json({error:e?.message||String(e)})}
};
