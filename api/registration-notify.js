const {sendRowTrainingMail}=require('../lib/mail');

function esc(v){
  return String(v??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]||c));
}

async function rest(url,{method='GET',key,body}={}){
  const r=await fetch(url,{
    method,
    headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json',Prefer:'return=representation'},
    body:body===undefined?undefined:JSON.stringify(body)
  });
  if(!r.ok) throw new Error(`supabase_${r.status}`);
  const txt=await r.text();
  return txt?JSON.parse(txt):null;
}

module.exports = async function handler(req,res){
  if(req.method!=="POST") return res.status(405).json({error:"method_not_allowed"});
  try{
    const token=(req.headers.authorization||"").replace(/^Bearer\s+/i,"");
    if(!token) return res.status(401).json({error:"missing_token"});

    const supabaseUrl=process.env.SUPABASE_URL || "https://bnvduwjisqosdjqypnvq.supabase.co";
    const apiKey=process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || "sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv";
    if(!apiKey) return res.status(204).end();

    const vr=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:apiKey,Authorization:`Bearer ${token}`}});
    if(!vr.ok) return res.status(401).json({error:"invalid_token"});
    const user=await vr.json();

    const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
    let requestRow=null;
    if(serviceKey){
      const rows=await rest(`${supabaseUrl}/rest/v1/registration_requests?user_id=eq.${encodeURIComponent(user.id)}&select=id,full_name,email,requested_team,status,notify_sent_at&limit=1`,{key:serviceKey});
      requestRow=Array.isArray(rows)?rows[0]||null:null;
      if(requestRow?.notify_sent_at) return res.status(200).json({ok:true,already_sent:true});
      if(requestRow && requestRow.status!=="pending") return res.status(200).json({ok:true,skipped:"not_pending"});
    }

    const to=process.env.REGISTRATION_NOTIFY_EMAIL || process.env.ROWTRAINING_GMAIL_USER;
    if(!to || !process.env.ROWTRAINING_GMAIL_USER || !process.env.ROWTRAINING_GMAIL_APP_PASSWORD) return res.status(204).end();

    const body=typeof req.body==="string"?JSON.parse(req.body||"{}"):req.body||{};
    const teamLabels={veteranas:"Veteranas femenino",senior_m:"Senior masculino",senior_f:"Senior femenino",veteranos_m:"Veteranos masculino"};
    const name=String(requestRow?.full_name||body.full_name||user.user_metadata?.full_name||user.email||"Nuevo remero").slice(0,160);
    const requestedTeam=requestRow?.requested_team||body.requested_team||null;
    const team=teamLabels[requestedTeam]||"Sin equipo preseleccionado";
    const email=String(requestRow?.email||user.email||"");

    const html=`<div style="font-family:Arial,Helvetica,sans-serif;color:#10233d;max-width:620px;margin:auto">
      <div style="background:#082b4c;color:white;padding:20px 24px;border-radius:14px 14px 0 0"><b style="font-size:22px">Row Training</b><br><span style="opacity:.85">Nueva inscripción pendiente</span></div>
      <div style="border:1px solid #dce5ee;border-top:0;padding:22px 24px;border-radius:0 0 14px 14px">
        <p>Hay una nueva solicitud de alta lista para revisar.</p>
        <p><b>Nombre:</b> ${esc(name)}</p>
        <p><b>Email:</b> ${esc(email)}</p>
        <p><b>Equipo invitado:</b> ${esc(team)}</p>
        <p><a href="https://rowtraining.vercel.app/" style="display:inline-block;background:#082b4c;color:#fff;text-decoration:none;padding:11px 16px;border-radius:9px;font-weight:700">Abrir Altas en Row Training</a></p>
      </div>
    </div>`;

    const info=await sendRowTrainingMail({
      to,
      subject:`Alta pendiente · ${name}`,
      html,
      text:`Nueva solicitud pendiente en Row Training. Nombre: ${name}. Email: ${email}. Equipo invitado: ${team}. Entra en Row Training > Altas para aprobarla.`
    });

    if(serviceKey && requestRow?.id){
      await rest(`${supabaseUrl}/rest/v1/registration_requests?id=eq.${requestRow.id}`,{method:'PATCH',key:serviceKey,body:{notify_sent_at:new Date().toISOString()}});
    }
    return res.status(200).json({ok:true,id:info.messageId||null,provider:"gmail"});
  }catch(e){
    return res.status(200).json({ok:false,email_warning:e?.message||"No se pudo enviar el aviso"});
  }
};
