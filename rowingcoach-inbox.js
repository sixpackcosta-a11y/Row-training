const {ImapFlow}=require('imapflow');
const {simpleParser}=require('mailparser');
const {parseAttachment}=require('../lib/rowingcoach');

async function rest(url,key){
  const response=await fetch(url,{headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json'}});
  const text=await response.text();
  if(!response.ok)throw new Error(`supabase_${response.status}_${text}`);
  return text?JSON.parse(text):null;
}

module.exports=async function handler(req,res){
  if(req.method!=='POST')return res.status(405).json({error:'method_not_allowed'});
  const supabaseUrl=process.env.SUPABASE_URL||'https://bnvduwjisqosdjqypnvq.supabase.co';
  const anonKey=process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY||'sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv';
  const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
  const gmailUser=process.env.ROWTRAINING_GMAIL_USER;
  const gmailPass=String(process.env.ROWTRAINING_GMAIL_APP_PASSWORD||'').replace(/\s+/g,'');
  if(!serviceKey)return res.status(500).json({error:'missing_service_role'});
  if(!gmailUser||!gmailPass)return res.status(500).json({error:'gmail_not_configured'});
  let client=null,lock=null;
  try{
    const token=(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
    if(!token)return res.status(401).json({error:'missing_token'});
    const verification=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:anonKey,Authorization:`Bearer ${token}`}});
    if(!verification.ok)return res.status(401).json({error:'invalid_token'});
    const user=await verification.json();
    const [globalRows,staffRows]=await Promise.all([
      rest(`${supabaseUrl}/rest/v1/user_roles?user_id=eq.${user.id}&role=eq.coach&select=user_id`,serviceKey),
      rest(`${supabaseUrl}/rest/v1/team_staff_roles?user_id=eq.${user.id}&staff_role=in.(coach,assistant)&select=user_id`,serviceKey)
    ]);
    if(!globalRows?.length&&!staffRows?.length)return res.status(403).json({error:'staff_required'});

    client=new ImapFlow({host:'imap.gmail.com',port:993,secure:true,auth:{user:gmailUser,pass:gmailPass},logger:false,connectionTimeout:15000,greetingTimeout:10000,socketTimeout:30000});
    await client.connect();
    lock=await client.getMailboxLock('INBOX');
    const since=new Date(Date.now()-45*86400000);
    const found=await client.search({since},{uid:true});
    const uids=(found||[]).slice(-60),logs=[];
    if(uids.length){
      for await(const message of client.fetch(uids,{uid:true,envelope:true,source:true},{uid:true})){
        const parsed=await simpleParser(message.source);
        for(const attachment of parsed.attachments||[]){
          if(!/\.(zip|csv)$/i.test(String(attachment.filename||'')))continue;
          try{
            const log=parseAttachment(attachment.filename,attachment.content,parsed.date||message.envelope?.date);
            if(!log)continue;
            const receivedValue=parsed.date||message.envelope?.date||new Date(),receivedDate=receivedValue instanceof Date?receivedValue:new Date(receivedValue);
            logs.push({...log,id:`${message.uid}:${attachment.checksum||attachment.filename}`,received_at:Number.isNaN(receivedDate.getTime())?new Date().toISOString():receivedDate.toISOString(),subject:String(parsed.subject||'Log Rowing Coach').slice(0,180)});
          }catch(error){/* Un adjunto ajeno o dañado no bloquea los demás. */}
        }
      }
    }
    logs.sort((a,b)=>String(b.received_at).localeCompare(String(a.received_at)));
    return res.status(200).json({ok:true,inbox:gmailUser,logs:logs.slice(0,20)});
  }catch(error){
    const message=String(error?.authenticationFailed? 'gmail_login_failed':error?.message||error);
    return res.status(500).json({error:message.slice(0,500)});
  }finally{
    try{if(lock)lock.release()}catch(_){ }
    try{if(client)await client.logout()}catch(_){ }
  }
};
