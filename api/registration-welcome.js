const {sendRowTrainingMail}=require('../lib/mail');
function esc(v){
  return String(v??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]||c));
}
function clean(v){return String(v??"").replace(/[<>]/g,"").trim()}

module.exports = async function handler(req,res){
  if(req.method!=="POST") return res.status(405).json({error:"method_not_allowed"});
  try{
    const token=(req.headers.authorization||"").replace(/^Bearer\s+/i,"");
    if(!token) return res.status(401).json({error:"missing_token"});

    const supabaseUrl=process.env.SUPABASE_URL || "https://bnvduwjisqosdjqypnvq.supabase.co";
    const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
    const apiKey=process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || serviceKey;
    if(!serviceKey || !apiKey) return res.status(503).json({error:"supabase_server_not_configured"});

    // 1) Verifica la sesión del usuario que llama.
    const vr=await fetch(`${supabaseUrl}/auth/v1/user`,{
      headers:{apikey:apiKey,Authorization:`Bearer ${token}`}
    });
    if(!vr.ok) return res.status(401).json({error:"invalid_token"});
    const caller=await vr.json();

    // 2) Solo un entrenador puede disparar el correo de bienvenida.
    const roleUrl=`${supabaseUrl}/rest/v1/user_roles?user_id=eq.${encodeURIComponent(caller.id)}&role=eq.coach&select=role&limit=1`;
    const rr=await fetch(roleUrl,{headers:{apikey:serviceKey,Authorization:`Bearer ${serviceKey}`}});
    if(!rr.ok) return res.status(500).json({error:"coach_check_failed"});
    const roles=await rr.json();
    if(!Array.isArray(roles)||!roles.length) return res.status(403).json({error:"coach_only"});

    const body=typeof req.body==="string"?JSON.parse(req.body||"{}"):req.body||{};
    const requestId=Number(body.request_id);
    if(!Number.isFinite(requestId)) return res.status(400).json({error:"invalid_request_id"});

    // 3) Lee la solicitud ya aprobada desde servidor.
    const reqUrl=`${supabaseUrl}/rest/v1/registration_requests?id=eq.${requestId}&select=id,full_name,email,status,assigned_team&limit=1`;
    const qr=await fetch(reqUrl,{headers:{apikey:serviceKey,Authorization:`Bearer ${serviceKey}`}});
    if(!qr.ok) return res.status(500).json({error:"request_lookup_failed"});
    const rows=await qr.json();
    const reg=Array.isArray(rows)?rows[0]:null;
    if(!reg) return res.status(404).json({error:"registration_not_found"});
    if(reg.status!=="approved") return res.status(409).json({error:"registration_not_approved"});
    if(!reg.email) return res.status(409).json({error:"registration_has_no_email"});

    if(!process.env.ROWTRAINING_GMAIL_USER || !process.env.ROWTRAINING_GMAIL_APP_PASSWORD){
      return res.status(503).json({error:"welcome_email_not_configured",message:"Falta configurar Gmail de Row Training en Vercel."});
    }

    const appUrl="https://rowtraining.vercel.app/";
    const helpUrl="https://rowtraining.vercel.app/?guia=1";
    const logoUrl="https://rowtraining.vercel.app/assets/club-pedregalejo.png";
    const teamLabels={
      veteranas:"Veteranas femenino",
      senior_m:"Senior masculino",
      senior_f:"Senior femenino",
      veteranos_m:"Veteranos masculino"
    };
    const team=teamLabels[reg.assigned_team]||"Tu equipo";
    const name=clean(reg.full_name)||"Remer@";

    const html=`<!doctype html><html><body style="margin:0;background:#f3f6fa;font-family:Arial,Helvetica,sans-serif;color:#10233d">
      <div style="max-width:650px;margin:0 auto;padding:24px 14px">
        <div style="background:#082b4c;border-radius:18px 18px 0 0;padding:22px;color:#fff;text-align:center">
          <img src="${logoUrl}" alt="Club de Remo Pedregalejo" width="78" height="78" style="object-fit:contain;border-radius:50%;vertical-align:middle">
          <h1 style="margin:10px 0 4px;font-size:26px">Bienvenid@ a Row Training</h1>
          <div style="opacity:.9">Club de Remo Pedregalejo · Tiburon@s</div>
        </div>
        <div style="background:#fff;padding:26px;border-radius:0 0 18px 18px;box-shadow:0 8px 24px rgba(9,39,68,.08)">
          <p style="font-size:17px;margin-top:0">Hola <b>${esc(name)}</b>,</p>
          <p>Tu inscripción ha sido aprobada y ya perteneces a <b>${esc(team)}</b>.</p>
          <p style="text-align:center;margin:26px 0"><a href="${appUrl}" style="display:inline-block;background:#082b4c;color:#fff;text-decoration:none;padding:13px 22px;border-radius:10px;font-weight:700">Abrir Row Training</a></p>

          <h2 style="font-size:18px">Añádela a la pantalla de inicio</h2>
          <div style="background:#eef5fb;border-radius:12px;padding:14px 16px;margin:10px 0"><b>iPhone / iPad</b><br>Abre Row Training en <b>Safari</b> → botón <b>Compartir</b> → <b>Añadir a pantalla de inicio</b> → Añadir.</div>
          <div style="background:#eef5fb;border-radius:12px;padding:14px 16px;margin:10px 0"><b>Android</b><br>Abre Row Training en <b>Chrome</b> → menú <b>⋮</b> → <b>Instalar aplicación</b> o <b>Añadir a pantalla de inicio</b>.</div>

          <h2 style="font-size:18px">Primeros pasos</h2>
          <ol style="padding-left:22px;line-height:1.55">
            <li><b>Perfil:</b> introduce peso, altura, FC de reposo y FC máxima. Row Training calcula tus zonas UT2, UT1, AT, TR y AN. Si conoces una FC máxima medida, úsala antes que una estimación.</li>
            <li><b>GYM:</b> las repeticiones ya están prescritas. Registra principalmente el peso y marca Fácil / Bien / Duro. Si no completas lo indicado con buena técnica, baja la carga.</li>
            <li><b>ERGO / ErgData:</b> en tu perfil conecta Concept2 una sola vez. En un día ERGO pulsa <b>Abrir entrenamiento en ErgData</b>, conecta ErgData al PM5 y realiza la sesión. Tras sincronizarse con tu Logbook de Concept2, Row Training puede importar el resultado.</li>
            <li><b>MAR:</b> en tu calendario verás “Sesión de mar”. El contenido completo lo prepara el entrenador.</li>
            <li><b>Historial:</b> consulta tus cargas de GYM, resultados de ERGO y evolución desde la app.</li>
          </ol>
          <p style="text-align:center;margin:24px 0 8px"><a href="${helpUrl}" style="color:#0b5ba8;font-weight:700">Ver guía completa de Row Training</a></p>
          <p style="font-size:12px;color:#6f8094;margin-top:24px">No respondas con contraseñas ni datos sensibles. Row Training nunca necesita tu contraseña de Concept2.</p>
        </div>
      </div></body></html>`;

    const info=await sendRowTrainingMail({
      to:reg.email,
      subject:`Ya estás dentro · Row Training · ${team}`,
      html,
      text:`Hola ${name}. Tu inscripción en Row Training ha sido aprobada y ya perteneces a ${team}. Abre la app: ${appUrl} · Guía: ${helpUrl}`
    });
    return res.status(200).json({ok:true,id:info.messageId||null,provider:"gmail"});
  }catch(e){
    return res.status(500).json({error:"welcome_email_failed",message:e?.message||"Error enviando bienvenida"});
  }
};
