async function rest(url,{method='GET',key,body}={}){
  const r=await fetch(url,{method,headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json',Prefer:'resolution=merge-duplicates,return=representation'},body:body===undefined?undefined:JSON.stringify(body)});
  if(!r.ok) throw new Error(`supabase_${r.status}_${await r.text()}`);
  const t=await r.text(); return t?JSON.parse(t):null;
}
module.exports=async function handler(req,res){
  if(req.method!=='POST')return res.status(405).json({error:'method_not_allowed'});
  const supabaseUrl=process.env.SUPABASE_URL||'https://bnvduwjisqosdjqypnvq.supabase.co';
  const apiKey=process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY||'sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv';
  const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!serviceKey)return res.status(500).json({error:'missing_service_role'});
  try{
    const token=(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
    if(!token)return res.status(401).json({error:'missing_token'});
    const vr=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:apiKey,Authorization:`Bearer ${token}`}});
    if(!vr.ok)return res.status(401).json({error:'invalid_token'});
    const user=await vr.json(); const s=req.body?.subscription;
    if(!s?.endpoint||!s?.keys?.p256dh||!s?.keys?.auth)return res.status(400).json({error:'bad_subscription'});
    await rest(`${supabaseUrl}/rest/v1/push_subscriptions?on_conflict=user_id,endpoint`,{method:'POST',key:serviceKey,body:{user_id:user.id,endpoint:s.endpoint,p256dh:s.keys.p256dh,auth:s.keys.auth,user_agent:String(req.headers['user-agent']||'').slice(0,500),updated_at:new Date().toISOString()}});
    return res.status(200).json({ok:true});
  }catch(e){return res.status(500).json({error:e.message});}
};
