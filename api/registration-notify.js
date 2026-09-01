const {sendRowTrainingMail}=require('../lib/mail');

function esc(v){
  return String(v??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]||c));
}

module.exports = async function handler(req,res){
  if(req.method!=="POST") return res.status(405).json({error:"method_not_allowed"});
  try{
    const token=(req.headers.authorization||"").replace(/^Bearer\s+/i,"");
    if(!token) return res.status(401).json({error:"missing_token"});

    const supabaseUrl=process.env.SUPABASE_URL || "https://bnvduwjisqosdjqypnvq.supabase.co";
    const apiKey=process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY;
    if(!apiKey) return res.status(204).end();

    const vr=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:apiKey,Authorization:`Bearer ${token}`}});
    if(!vr.ok) return res.status(401).json({error:"invalid_token"});
    const user=await vr.json();

    // El aviso por email es complementario al contador Altas de la app.
    // Si no se configura destinatario, llega a la propia cuenta de Row Training.
    const to=process.env.REGISTRATION_NOTIFY_EMAIL || process.env.ROWTRAINING_GMAIL_USER;
    if(!to || !process.env.ROWTRAINING_GMAIL_USER || !process.env.ROWTRAINING_GMAIL_APP_PASSWORD) return res.status(204).end();

    const body=typeof req.body==="string"?JSON.parse(req.body||"{}"):req.body||{};
    const teamLabels={veteranas:"Veteranas femenino",senior_m:"Senior masculino",senior_f:"Senior femenino",veteranos_m:"Veteranos masculino"};
    const name=String(body.full_name||user.user_metadata?.full_name||user.email||"Nuevo remero").slice(0,160);
    const team=teamLabels[body.requested_team]||"Sin equipo preseleccionado";
    const email=String(user.email||"");

    const html=`<div style="font-family:Arial,Helvetica,sans-serif;color:#10233d;max-width:620px;margin:auto">
      <div style="background:#082b4c;color:white;padding:20px 24px;border-radius:14px 14px 0 0"><b style="font-size:22px">Row Training</b><br><span style="opacity:.85">Nueva inscripción</span></div>
      <div style="border:1px solid #dce5ee;border-top:0;padding:22px 24px;border-radius:0 0 14px 14px">
        <p><b>Nombre:</b> ${esc(name)}</p>
        <p><b>Email:</b> ${esc(email)}</p>
        <p><b>Equipo invitado:</b> ${esc(team)}</p>
        <p>La solicitud está pendiente en el apartado <b>Altas</b> del panel de entrenador.</p>
        <p><a href="https://rowtraining.vercel.app/" style="display:inline-block;background:#082b4c;color:#fff;text-decoration:none;padding:11px 16px;border-radius:9px;font-weight:700">Abrir Row Training</a></p>
      </div>
    </div>`;

    const info=await sendRowTrainingMail({
      to,
      subject:`Nueva inscripción · ${name}`,
      html,
      text:`Nueva inscripción en Row Training. Nombre: ${name}. Email: ${email}. Equipo invitado: ${team}.`
    });
    return res.status(200).json({ok:true,id:info.messageId||null,provider:"gmail"});
  }catch(e){
    // El registro no debe fallar porque el aviso por email falle.
    return res.status(200).json({ok:false,email_warning:e?.message||"No se pudo enviar el aviso"});
  }
};
