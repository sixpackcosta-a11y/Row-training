const {sendRowTrainingMail}=require('../lib/mail');
const webpush=require('web-push');

function esc(v){
  return String(v??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]||c));
}

async function rest(url,{method='GET',key,body,prefer}={}){
  const r=await fetch(url,{
    method,
    headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json',Prefer:prefer||'return=representation'},
    body:body===undefined?undefined:JSON.stringify(body)
  });
  if(!r.ok) throw new Error(`supabase_${r.status}`);
  const txt=await r.text();
  return txt?JSON.parse(txt):null;
}

function validUuid(v){
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(v||''));
}

module.exports = async function handler(req,res){
  if(req.method!=="POST") return res.status(405).json({error:"method_not_allowed"});

  const body=typeof req.body==="string"?JSON.parse(req.body||"{}"):req.body||{};
  const supabaseUrl=process.env.SUPABASE_URL || "https://bnvduwjisqosdjqypnvq.supabase.co";
  const apiKey=process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || "sb_publishable_H7nlpeJccVutM2iN3-5iHQ_WjFQGAqv";
  const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;

  try{
    if(!apiKey) return res.status(204).end();

    // V82: tras signUp con confirmación de email, Supabase devuelve user pero session=null.
    // Permitimos el primer aviso usando user_id + service role; tras confirmar correo se mantiene
    // el segundo intento autenticado. notify_sent_at evita duplicados.
    const token=(req.headers.authorization||"").replace(/^Bearer\s+/i,"");
    let user=null;
    let userId=null;

    if(token){
      const vr=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:apiKey,Authorization:`Bearer ${token}`}});
      if(!vr.ok) return res.status(401).json({error:"invalid_token"});
      user=await vr.json();
      userId=user?.id||null;
    }else{
      if(!serviceKey) return res.status(204).end();
      userId=String(body.user_id||"");
      if(!validUuid(userId)) return res.status(400).json({error:"missing_user_id"});
    }

    let requestRow=null;
    if(serviceKey){
      const rows=await rest(`${supabaseUrl}/rest/v1/registration_requests?user_id=eq.${encodeURIComponent(userId)}&select=id,user_id,full_name,email,requested_team,status,notify_sent_at&limit=1`,{key:serviceKey});
      requestRow=Array.isArray(rows)?rows[0]||null:null;
      if(!requestRow) return res.status(202).json({ok:false,skipped:"request_not_ready"});
      if(requestRow.status!=="pending") return res.status(200).json({ok:true,skipped:"not_pending"});
      if(requestRow.notify_sent_at) return res.status(200).json({ok:true,already_sent:true});
    }else if(!user){
      return res.status(204).end();
    }

    // V104: crea aviso interno y, si el entrenador activó push, envía notificación al móvil.
    // Los destinatarios son el entrenador administrador y los entrenadores del equipo solicitado.
    if(serviceKey && requestRow){
      try{
        const globalRows=await rest(`${supabaseUrl}/rest/v1/user_roles?role=eq.coach&select=user_id`,{key:serviceKey})||[];
        let teamRows=[];
        if(requestRow.requested_team){
          teamRows=await rest(`${supabaseUrl}/rest/v1/team_staff_roles?team_code=eq.${encodeURIComponent(requestRow.requested_team)}&staff_role=eq.coach&select=user_id`,{key:serviceKey})||[];
        }
        const coachIds=[...new Set([...globalRows,...teamRows].map(x=>x.user_id).filter(Boolean))];
        const teamLabelsV104={veteranas:'Veteranas femenino',senior_m:'Senior masculino',senior_f:'Senior femenino',veteranos_m:'Veteranos masculino'};
        const nName=String(requestRow.full_name||requestRow.email||'Nuevo remero').slice(0,160);
        const nTeam=teamLabelsV104[requestRow.requested_team]||'Sin equipo preseleccionado';
        const pushCoachIds=[];
        for(const uid of coachIds){
          const sourceKey=`registration:${requestRow.id}`;
          const previous=await rest(`${supabaseUrl}/rest/v1/app_notifications?user_id=eq.${encodeURIComponent(uid)}&source_key=eq.${encodeURIComponent(sourceKey)}&select=id&limit=1`,{key:serviceKey})||[];
          if(previous.length)continue;
          const inserted=await rest(`${supabaseUrl}/rest/v1/app_notifications`,{method:'POST',key:serviceKey,prefer:'return=representation',body:{user_id:uid,type:'registration',title:'Nueva alta pendiente',body:`${nName} · ${nTeam}`,url:'/?tab=altas',source_key:sourceKey}});
          if(Array.isArray(inserted)&&inserted.length)pushCoachIds.push(uid);
        }
        const pub=process.env.VAPID_PUBLIC_KEY,priv=process.env.VAPID_PRIVATE_KEY;
        if(pub&&priv&&pushCoachIds.length){
          webpush.setVapidDetails('https://rowtraining.vercel.app',pub,priv);
          const ids=pushCoachIds.map(encodeURIComponent).join(',');
          const subs=await rest(`${supabaseUrl}/rest/v1/push_subscriptions?user_id=in.(${ids})&select=id,user_id,endpoint,p256dh,auth`,{key:serviceKey})||[];
          for(const ps of subs){
            try{
              await webpush.sendNotification({endpoint:ps.endpoint,keys:{p256dh:ps.p256dh,auth:ps.auth}},JSON.stringify({title:'Nueva alta en Row Training',body:`${nName} · ${nTeam}`,url:'/?tab=altas',tag:`registration-${requestRow.id}`}));
            }catch(pushErr){
              if(pushErr?.statusCode===404||pushErr?.statusCode===410){try{await rest(`${supabaseUrl}/rest/v1/push_subscriptions?id=eq.${ps.id}`,{method:'DELETE',key:serviceKey});}catch(e){}}
            }
          }
        }
      }catch(pushError){ console.warn('push_notification_warning',pushError?.message||pushError); }
    }

    const to=process.env.REGISTRATION_NOTIFY_EMAIL || process.env.ROWTRAINING_GMAIL_USER;
    // El push/aviso interno no depende de Gmail. Si el correo no está configurado, terminamos aquí con éxito.
    if(!to || !process.env.ROWTRAINING_GMAIL_USER || !process.env.ROWTRAINING_GMAIL_APP_PASSWORD) return res.status(200).json({ok:true,push:true,email:false});

    // Reserva atómica del aviso para que dos intentos simultáneos no manden dos correos.
    let claimedAt=null;
    if(serviceKey && requestRow?.id){
      claimedAt=new Date().toISOString();
      const claimed=await rest(`${supabaseUrl}/rest/v1/registration_requests?id=eq.${requestRow.id}&notify_sent_at=is.null`,{
        method:'PATCH',key:serviceKey,body:{notify_sent_at:claimedAt}
      });
      if(!Array.isArray(claimed) || !claimed.length) return res.status(200).json({ok:true,already_sent:true});
    }

    const teamLabels={veteranas:"Veteranas femenino",senior_m:"Senior masculino",senior_f:"Senior femenino",veteranos_m:"Veteranos masculino"};
    const name=String(requestRow?.full_name||body.full_name||user?.user_metadata?.full_name||user?.email||"Nuevo remero").slice(0,160);
    const requestedTeam=requestRow?.requested_team||body.requested_team||null;
    const team=teamLabels[requestedTeam]||"Sin equipo preseleccionado";
    const email=String(requestRow?.email||user?.email||body.email||"");

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

    try{
      const info=await sendRowTrainingMail({
        to,
        subject:`Alta pendiente · ${name}`,
        html,
        text:`Nueva solicitud pendiente en Row Training. Nombre: ${name}. Email: ${email}. Equipo invitado: ${team}. Entra en Row Training > Altas para aprobarla.`
      });
      return res.status(200).json({ok:true,id:info.messageId||null,provider:"gmail"});
    }catch(mailError){
      // Si Gmail falla, libera la reserva para que el segundo intento tras confirmar pueda reenviar.
      if(serviceKey && requestRow?.id && claimedAt){
        try{
          await rest(`${supabaseUrl}/rest/v1/registration_requests?id=eq.${requestRow.id}&notify_sent_at=eq.${encodeURIComponent(claimedAt)}`,{
            method:'PATCH',key:serviceKey,body:{notify_sent_at:null}
          });
        }catch(e){}
      }
      throw mailError;
    }
  }catch(e){
    return res.status(200).json({ok:false,email_warning:e?.message||"No se pudo enviar el aviso"});
  }
};
