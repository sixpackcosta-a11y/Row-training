module.exports = async function handler(req,res){
  if(req.method!=="POST") return res.status(405).json({error:"method_not_allowed"});
  const resend=process.env.RESEND_API_KEY;
  const to=process.env.REGISTRATION_NOTIFY_EMAIL;
  const from=process.env.REGISTRATION_FROM_EMAIL || "Row Training <onboarding@resend.dev>";
  // El email es opcional. La notificación dentro de Row Training funciona sin estas variables.
  if(!resend || !to) return res.status(204).end();
  try{
    const token=(req.headers.authorization||"").replace(/^Bearer\s+/i,"");
    if(!token) return res.status(401).json({error:"missing_token"});
    const supabaseUrl=process.env.SUPABASE_URL || "https://bnvduwjisqosdjqypnvq.supabase.co";
    const apiKey=process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY;
    if(!apiKey) return res.status(204).end();
    const vr=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:apiKey,Authorization:`Bearer ${token}`}});
    if(!vr.ok) return res.status(401).json({error:"invalid_token"});
    const user=await vr.json();
    const body=req.body||{};
    const teamLabels={veteranas:"Veteranas femenino",senior_m:"Senior masculino",senior_f:"Senior femenino",veteranos_m:"Veteranos masculino"};
    const name=String(body.full_name||user.user_metadata?.full_name||user.email||"Nuevo remero").slice(0,160);
    const team=teamLabels[body.requested_team]||"Sin equipo preseleccionado";
    const rr=await fetch("https://api.resend.com/emails",{method:"POST",headers:{Authorization:`Bearer ${resend}`,"Content-Type":"application/json"},body:JSON.stringify({from,to:[to],subject:"Nueva inscripción · Row Training",html:`<h2>Nueva inscripción en Row Training</h2><p><b>Nombre:</b> ${name.replace(/[<>]/g,"")}</p><p><b>Email:</b> ${String(user.email||"").replace(/[<>]/g,"")}</p><p><b>Equipo invitado:</b> ${team}</p><p>La solicitud está pendiente en el panel <b>Altas</b>.</p>`})});
    if(!rr.ok) return res.status(502).json({error:"email_failed"});
    return res.status(200).json({ok:true});
  }catch(e){return res.status(500).json({error:"notify_failed"})}
};
