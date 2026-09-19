const crypto=require('crypto');
async function rest(url,{method='GET',key,token,body,prefer}={}){
  const response=await fetch(url,{method,headers:{apikey:key,Authorization:`Bearer ${token||key}`,'Content-Type':'application/json',...(prefer?{Prefer:prefer}:{})},body:body===undefined?undefined:JSON.stringify(body)});
  const text=await response.text();
  if(!response.ok)throw new Error(`supabase_${response.status}_${text}`);
  return text?JSON.parse(text):null;
}
function sha256Hex(text){
  return crypto.createHash('sha256').update(text,'utf8').digest('hex');
}
const DEEPL_TARGETS={en:'EN-GB',nl:'NL'};

module.exports=async function handler(req,res){
  if(req.method!=='POST')return res.status(405).json({error:'method_not_allowed'});
  const supabaseUrl=process.env.SUPABASE_URL||'https://bnvduwjisqosdjqypnvq.supabase.co';
  const anonKey=process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY||'sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv';
  const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
  const deeplKey=process.env.DEEPL_API_KEY;
  if(!serviceKey)return res.status(500).json({error:'missing_service_role'});
  if(!deeplKey)return res.status(500).json({error:'missing_deepl_key'});
  try{
    const token=String(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
    if(!token)return res.status(401).json({error:'missing_token'});
    const auth=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:anonKey,Authorization:`Bearer ${token}`}});
    if(!auth.ok)return res.status(401).json({error:'invalid_token'});

    const text=String(req.body?.text||'').trim();
    const targetLang=String(req.body?.target_lang||'').toLowerCase();
    if(!text)return res.status(200).json({translated:''});
    if(text.length>3000)return res.status(400).json({error:'text_too_long'});
    if(!DEEPL_TARGETS[targetLang])return res.status(400).json({error:'bad_target_lang'});

    const hash=await sha256Hex(text);
    const cached=await rest(`${supabaseUrl}/rest/v1/translation_cache?source_hash=eq.${hash}&target_lang=eq.${targetLang}&select=translated_text&limit=1`,{key:serviceKey});
    if(cached?.length)return res.status(200).json({translated:cached[0].translated_text,cached:true});

    const deeplResponse=await fetch('https://api-free.deepl.com/v2/translate',{
      method:'POST',
      headers:{'Authorization':`DeepL-Auth-Key ${deeplKey}`,'Content-Type':'application/json'},
      body:JSON.stringify({text:[text],target_lang:DEEPL_TARGETS[targetLang],source_lang:'ES'})
    });
    if(!deeplResponse.ok){
      const errText=await deeplResponse.text().catch(()=>'');
      return res.status(502).json({error:'deepl_error',detail:errText.slice(0,300)});
    }
    const deeplData=await deeplResponse.json();
    const translated=deeplData?.translations?.[0]?.text||text;

    await rest(`${supabaseUrl}/rest/v1/translation_cache`,{method:'POST',key:serviceKey,prefer:'resolution=ignore-duplicates',body:{source_hash:hash,target_lang:targetLang,source_text:text,translated_text:translated}}).catch(()=>{});

    return res.status(200).json({translated,cached:false});
  }catch(e){
    return res.status(500).json({error:'server_error',detail:String(e?.message||e).slice(0,300)});
  }
};
