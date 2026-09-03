const webpush=require('web-push');
async function rest(url,{apiKey,token}={}){const r=await fetch(url,{headers:{apikey:apiKey,Authorization:`Bearer ${token}`,'Content-Type':'application/json'}});const t=await r.text();if(!r.ok)throw new Error(`supabase_${r.status}_${t}`);return t?JSON.parse(t):null;}
module.exports=async function handler(req,res){
 if(req.method!=='POST')return res.status(405).json({error:'method_not_allowed'});
 const supabaseUrl=process.env.SUPABASE_URL||'https://bnvduwjisqosdjqypnvq.supabase.co';
 const anonKey=process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY||'sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv';
 const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
 try{
  const userToken=(req.headers.authorization||'').replace(/^Bearer\s+/i,'');if(!userToken)return res.status(401).json({error:'missing_token'});
  const vr=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:anonKey,Authorization:`Bearer ${userToken}`}});if(!vr.ok)return res.status(401).json({error:'invalid_token'});const user=await vr.json();
  const pub=process.env.VAPID_PUBLIC_KEY,priv=process.env.VAPID_PRIVATE_KEY;if(!pub||!priv)return res.status(400).json({error:'push_not_configured'});
  webpush.setVapidDetails('https://rowtraining.vercel.app',pub,priv);
  const apiKey=serviceKey||anonKey,token=serviceKey||userToken;
  const subs=await rest(`${supabaseUrl}/rest/v1/push_subscriptions?user_id=eq.${user.id}&select=id,endpoint,p256dh,auth`,{apiKey,token});
  let sent=0;const errors=[];
  for(const s of subs||[]){try{await webpush.sendNotification({endpoint:s.endpoint,keys:{p256dh:s.p256dh,auth:s.auth}},JSON.stringify({title:'Row Training',body:'Las notificaciones push están funcionando ✅',url:'/'}));sent++;}catch(e){errors.push({statusCode:e?.statusCode||null,message:String(e?.body||e?.message||e).slice(0,500)});}}
  return res.json({ok:true,found:(subs||[]).length,sent,errors});
 }catch(e){return res.status(500).json({error:e.message});}
};
