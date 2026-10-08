// V713 · Los avisos "Faltan N" y de mar van solo a los entrenadores/ayudantes del equipo del evento y a quien lo creó u organiza.
// V706 · Interruptores por tipo de aviso en la app (⚙ Ajustes → Avisos automáticos, tabla cron_settings, SQL 73) y por variables CRON_OPENS/CRON_REMINDERS/CRON_SHORT/CRON_SEA=0.
// V705 · MODO PRUEBA por defecto: no envía ni marca nada (devuelve en 'would' lo que enviaría). Para enviar de verdad: variable CRON_LIVE=1 en Vercel.
// V705 · Añade aviso de previsión de mar al equipo técnico (el día antes a las 20:00 y 3 h antes) usando los umbrales del club (tabla sea_thresholds, SQL 72).
// V676 · Cron de eventos (se llama cada 15 min desde Supabase pg_cron, ver 66_cron_eventos.sql).
// Hace tres cosas, sin que nadie tenga que abrir la app:
//  1) "📅 Ya puedes confirmar asistencia" a la hora exacta de apertura (cerrojo opens_notified_at).
//  2) "🔔 ¿Vas a …?" a quien no ha respondido, a las horas configuradas en el evento (cerrojo reminder_sent_at).
//  3) Al equipo técnico: "👥 Faltan N para salir en barca/llaut" cuando falta menos de un día y no se llega al mínimo.
// Usa los mismos cerrojos que la app, así que si alguien abre Eventos a la vez nunca se manda dos veces.
const {deliverNotifications}=require('./push-send');

const SB_URL=process.env.SUPABASE_URL||'https://bnvduwjisqosdjqypnvq.supabase.co';
const BOAT_MIN={barca:7,llaut:8};
const uniq=a=>[...new Set((a||[]).filter(Boolean).map(String))];
async function rest(path,{method='GET',body,prefer}={}){
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  const r=await fetch(`${SB_URL}/rest/v1/${path}`,{method,headers:{apikey:key,Authorization:`Bearer ${key}`,'Content-Type':'application/json',...(prefer?{Prefer:prefer}:{})},body:body===undefined?undefined:JSON.stringify(body)});
  const t=await r.text();if(!r.ok)throw new Error(`supabase_${r.status}_${t.slice(0,200)}`);
  return t?JSON.parse(t):null;
}
// hora local de Madrid como texto "YYYY-MM-DDTHH:MM" (se compara como texto; sumas/restas con Date en UTC "ingenuo")
function madridNow(){
  const p=Object.fromEntries(new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Madrid',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(new Date()).map(x=>[x.type,x.value]));
  return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`;
}
const WX_DEF={lat:36.712,lon:-4.352,waveAmber:0.6,waveRed:1.0,windAmber:20,windRed:30,gustAmber:30,gustRed:40,rainAmber:60,defHour:10,defDur:2};
async function wxLoad(c){
  const tz='Europe%2FMadrid',H={};
  const mu=`https://marine-api.open-meteo.com/v1/marine?latitude=${c.lat}&longitude=${c.lon}&hourly=wave_height,wave_period&timezone=${tz}&past_days=1&forecast_days=10`;
  const fu=`https://api.open-meteo.com/v1/forecast?latitude=${c.lat}&longitude=${c.lon}&hourly=wind_speed_10m,wind_gusts_10m,precipitation_probability,weather_code&wind_speed_unit=kmh&timezone=${tz}&past_days=1&forecast_days=10`;
  const [a,b]=await Promise.allSettled([fetch(mu).then(r=>r.json()),fetch(fu).then(r=>r.json())]);
  const add=(j,f)=>{const h=j&&j.hourly;if(!h||!h.time)return;h.time.forEach((t,i)=>{const o=H[t]||(H[t]={});for(const [src,dst] of f){if(h[src]&&h[src][i]!=null)o[dst]=h[src][i]}})};
  add(a.status==='fulfilled'?a.value:null,[['wave_height','wave'],['wave_period','period']]);
  add(b.status==='fulfilled'?b.value:null,[['wind_speed_10m','wind'],['wind_gusts_10m','gust'],['precipitation_probability','pop'],['weather_code','code']]);
  return H;
}
function wxEval(H,date,time,end,c){
  const pad=n=>String(n).padStart(2,'0');
  let sh=c.defHour;if(/^\d{1,2}:\d{2}/.test(time||''))sh=Number(time.split(':')[0]);
  let eh=sh+c.defDur;if(/^\d{1,2}:\d{2}/.test(end||'')){const x=Number(end.split(':')[0])+(Number(end.split(':')[1])>0?1:0);if(x>sh)eh=x}
  eh=Math.min(Math.max(eh,sh+1),sh+6,24);
  const rows=[];for(let h=sh;h<eh&&h<24;h++){const r=H[`${date}T${pad(h)}:00`];if(r)rows.push(r)}
  if(!rows.length)return null;
  const mx=f=>{const v=rows.map(r=>r[f]).filter(x=>x!=null);return v.length?Math.max(...v):null};
  const m={wave:mx('wave'),wind:mx('wind'),gust:mx('gust'),pop:mx('pop'),code:mx('code')};
  const red=[],amb=[];
  const chk=(v,a,r,lab,u,d)=>{if(v==null)return;const t=`${lab} ${Number(v).toFixed(d).replace('.',',')} ${u}`;if(v>=r)red.push(t);else if(v>=a)amb.push(t)};
  chk(m.wave,c.waveAmber,c.waveRed,'olas','m',1);chk(m.wind,c.windAmber,c.windRed,'viento','km/h',0);chk(m.gust,c.gustAmber,c.gustRed,'rachas','km/h',0);
  if(m.code!=null&&m.code>=95)red.push('tormenta prevista');
  const level=red.length?'red':amb.length?'amber':(m.wave!=null&&m.wind!=null)?'ok':'unk';
  return {level,reasons:red.concat(amb),m};
}
const toMs=s=>Date.parse(s+':00Z');
const fromMs=ms=>new Date(ms).toISOString().slice(0,16);
const hhmm=t=>/^\d{1,2}:\d{2}/.test(t||'')?String(t).slice(0,5).padStart(5,'0'):null;
function addDays(d,n){const x=new Date(d+'T12:00:00Z');x.setUTCDate(x.getUTCDate()+n);return x.toISOString().slice(0,10)}
function dateLabel(d,t){const [y,m,dd]=d.split('-');return `${dd}/${m}${hhmm(t)?' · '+hhmm(t):''}`}

module.exports=async function handler(req,res){
  const secret=process.env.CRON_SECRET;
  if(!secret||(req.headers.authorization||'')!==`Bearer ${secret}`)return res.status(401).json({error:'unauthorized'});
  if(!process.env.SUPABASE_SERVICE_ROLE_KEY)return res.status(500).json({error:'missing_service_role'});
  const LIVE=process.env.CRON_LIVE==='1';
  const ON=k=>process.env[k]!=='0'; // bloques: activos salvo que la variable valga 0
  const F={opens:ON('CRON_OPENS'),reminders:ON('CRON_REMINDERS'),short:ON('CRON_SHORT'),sea:ON('CRON_SEA')};
  const out={live:LIVE,blocks:F,opens:0,reminders:0,shortage:0,weather:0,would:[],errors:[]};
  try{
    // V706 · interruptores del panel de la app (tabla cron_settings). Sin fila: aperturas y recordatorios sí, "faltan" y mar no. La variable CRON_x=0 en Vercel apaga el bloque siempre.
    try{
      const rr=await rest('cron_settings?id=eq.1&select=cfg');
      const c={opens:true,reminders:true,short:false,sea:false,paused:false,...((rr&&rr[0]&&rr[0].cfg)||{})};
      for(const k of Object.keys(F))F[k]=F[k]&&!c.paused&&c[k]===true;
    }catch(e){for(const k of Object.keys(F))F[k]=F[k]&&(k==='opens'||k==='reminders')}
    const nowQ=(!LIVE&&req.query&&/^\d{4}-\d\d-\d\dT\d\d:\d\d$/.test(String(req.query.now||'')))?String(req.query.now):null;
    const now=nowQ||madridNow(),today=now.slice(0,10),from=addDays(today,-1),to=addDays(today,60);
    const [teamsRows,prefsRows,ss,cc,ee]=await Promise.all([
      rest('rowing_teams?select=code,events_rowers_live'),
      rest('notification_prefs?select=user_id,prefs').catch(()=>[]),
      rest(`training_sessions?is_event=eq.true&target_user_ids=is.null&cancelled_at=is.null&session_date=gte.${from}&session_date=lte.${to}&select=*`).catch(e=>{out.errors.push('sessions:'+e.message);return []}),
      rest(`competitions?cancelled_at=is.null&competition_date=gte.${from}&competition_date=lte.${to}&select=*`).catch(e=>{out.errors.push('comps:'+e.message);return []}),
      rest(`club_events?cancelled_at=is.null&event_date=gte.${from}&event_date=lte.${to}&select=*`).catch(e=>{out.errors.push('club:'+e.message);return []})
    ]);
    const live=new Set((teamsRows||[]).filter(t=>t.events_rowers_live===true).map(t=>t.code));
    const prefs=new Map((prefsRows||[]).map(r=>[String(r.user_id),r.prefs||{}]));
    const blocks=(uid,cat)=>(prefs.get(String(uid))||{})[cat]===false;
    const table={session:'training_sessions',competition:'competitions',club_event:'club_events'};
    const events=[
      ...(ss||[]).map(x=>({...x,kind:'session',date:x.session_date,title:x.event_name||x.title||'Entrenamiento',teams:[x.team_code]})),
      ...(cc||[]).map(x=>({...x,kind:'competition',date:x.competition_date,title:x.name||'Competición',teams:x.team_codes||[]})),
      ...(ee||[]).map(x=>({...x,kind:'club_event',date:x.event_date,title:x.title||'Evento',teams:uniq([x.team_code,...(x.extra_team_codes||[])])}))
    ].filter(e=>e.teams.length);
    // staff por equipo
    const [staffRows,gcRows,orgRows]=await Promise.all([rest('team_staff_roles?select=user_id,team_code'),rest('user_roles?role=eq.coach&select=user_id'),rest('event_organizers?select=user_id,training_session_id,competition_id,club_event_id').catch(()=>[])]);
    const staffOf=teams=>uniq([...(staffRows||[]).filter(r=>teams.includes(r.team_code)).map(r=>r.user_id),...(gcRows||[]).map(r=>r.user_id)]);
    // V713 · avisos al equipo técnico: solo entrenadores/ayudantes de los equipos del evento + quien lo creó u organiza (si es del equipo técnico). Ya no a todos los entrenadores globales.
    const staffAll=new Set([...(staffRows||[]).map(r=>String(r.user_id)),...(gcRows||[]).map(r=>String(r.user_id))]);
    const techOf=(e,teams)=>{
      const col=e.kind==='session'?'training_session_id':e.kind==='competition'?'competition_id':'club_event_id';
      const org=(orgRows||[]).filter(o=>String(o[col])===String(e.id)).map(o=>o.user_id);
      return uniq([...(staffRows||[]).filter(r=>teams.includes(r.team_code)).map(r=>r.user_id),...[e.created_by,...org].filter(Boolean).map(String).filter(i=>staffAll.has(i))]);
    };
    const rosterCache=new Map();
    const rosterOf=async team=>{if(!rosterCache.has(team))rosterCache.set(team,uniq((await rest(`rower_team_memberships?team_code=eq.${encodeURIComponent(team)}&is_rower=eq.true&select=user_id`)||[]).map(r=>r.user_id)));return rosterCache.get(team)};
    const rsvpOf=async(e,team)=>{
      const col=e.kind==='session'?'training_session_id':e.kind==='competition'?'competition_id':'club_event_id';
      const teamF=e.kind==='club_event'?'':`&team_code=eq.${encodeURIComponent(team)}`;
      return await rest(`session_rsvp?${col}=eq.${e.id}${teamF}&select=user_id,status`)||[];
    };
    const audience=async(e,team)=>{ // remeras del evento en ese equipo, respetando invitados/excluidos
      let ids=await rosterOf(team);
      if(e.kind==='club_event'&&Array.isArray(e.invitee_ids)&&e.invitee_ids.length)ids=ids.filter(i=>e.invitee_ids.map(String).includes(i));
      const ex=(e.excluded_ids||[]).map(String);return ids.filter(i=>!ex.includes(i));
    };
    const url=(e,team)=>`/?tab=eventos&ek=${e.kind}&eid=${e.id}&et=${encodeURIComponent(team)}`;
    const claim=async(e,col)=>{if(!LIVE)return true;const r=await rest(`${table[e.kind]}?id=eq.${e.id}&${col}=is.null`,{method:'PATCH',body:{[col]:new Date().toISOString()},prefer:'return=representation'});return Array.isArray(r)&&r.length>0};
    const send=(recipientIds,title,body,u,type,sourceBase)=>!LIVE?(out.would.push({para:recipientIds.length+' personas',title,body,ref:sourceBase}),Promise.resolve()):deliverNotifications({supabaseUrl:SB_URL,serviceKey:process.env.SUPABASE_SERVICE_ROLE_KEY,recipientIds,title,body,url:u,type,sourceBase});

    // umbrales del club (SQL 72) y previsión, solo si hay algún evento de mar en las próximas 36 h
    let wxCfg=null,wxH=null;
    const wxGet=async()=>{if(!wxCfg){const r=await rest('sea_thresholds?id=eq.1&select=cfg').catch(()=>null);wxCfg={...WX_DEF,...((r&&r[0]&&r[0].cfg)||{})}}if(!wxH)wxH=await wxLoad(wxCfg);return {c:wxCfg,H:wxH}};
    for(const e of events){
      try{
        const liveTeams=e.teams.filter(t=>live.has(t));
        // hora de apertura
        let opensAt=null;
        if(e.rsvp_open_days_before||e.rsvp_open_time){opensAt=`${addDays(e.date,-(e.rsvp_open_days_before||0))}T${hhmm(e.rsvp_open_time)||'00:00'}`}
        const isOpen=!opensAt||opensAt<=now;
        // 1) apertura
        if(F.opens&&opensAt&&opensAt<=now&&!e.opens_notified_at&&liveTeams.length&&e.date>=today){
          if(await claim(e,'opens_notified_at')){
            let ids=[];for(const t of liveTeams)ids.push(...await audience(e,t));
            ids=uniq(ids).filter(i=>!blocks(i,'event_new'));
            if(ids.length)await send(ids,'📅 Ya puedes confirmar asistencia',`Confirma tu asistencia a "${e.title}" (${dateLabel(e.date,e.event_time)}) en Row Training.`,url(e,liveTeams[0]),'training',`cron_open:${e.kind}:${e.id}`);
            out.opens++;
          }
        }
        // 2) recordatorio a quien no ha respondido
        if(F.reminders&&e.reminder_hours_before&&!e.reminder_sent_at&&liveTeams.length&&isOpen){
          const st=`${e.date}T${hhmm(e.meet_time||e.event_time)||'09:00'}`,remindAt=fromMs(toMs(st)-e.reminder_hours_before*3600000);
          if(now>=remindAt&&now<st){
            if(await claim(e,'reminder_sent_at')){
              for(const t of liveTeams){
                const answered=new Set((await rsvpOf(e,t)).map(r=>String(r.user_id)));
                const pend=(await audience(e,t)).filter(i=>!answered.has(i)&&!blocks(i,'event_reminder'));
                if(pend.length)await send(pend,`🔔 ¿Vas a ${e.title}?`,`Aún no has respondido a "${e.title}" (${dateLabel(e.date,e.event_time)}). Confirma en Row Training.`,url(e,t),'training',`cron_rem:${e.kind}:${e.id}:${t}`);
              }
              out.reminders++;
            }
          }
        }
        // 3) falta gente (equipo técnico), una vez, cuando faltan menos de 26 h
        const startS=`${e.date}T${hhmm(e.event_time)||'09:00'}`;
        const hoursTo=(toMs(startS)-toMs(now))/3600000;
        const boatApplies=e.boat_type||(e.kind==='session'&&e.session_type==='MAR')||e.kind==='competition';
        if(F.short&&boatApplies&&isOpen&&hoursTo>25.75&&hoursTo<=26){
          for(const t of e.teams){
            const need=e.boat_type?BOAT_MIN[e.boat_type]:BOAT_MIN.barca; // sin decidir: se avisa solo si no llega ni a barca
            const rid=new Set(await rosterOf(t));const going=(await rsvpOf(e,t)).filter(r=>r.status==='in'&&rid.has(String(r.user_id))).length; // el equipo técnico no cuenta
            if(going<need){
              const falta=need-going,que=e.boat_type?`salir en ${e.boat_type}`:'poder salir en barca';
              await send(techOf(e,[t]),`👥 Faltan ${falta} para ${que}`,`${t.toUpperCase().slice(0,12)} · ${e.title} (${dateLabel(e.date,e.event_time)}): van ${going} de ${need} mínimo.`,url(e,t),'training',`cron_short:${e.kind}:${e.id}:${t}`);
              out.shortage++;
            }
          }
        }
        // 4) previsión de mar: al equipo técnico, el día antes a las 20:00 y 3 h antes, solo si hay precaución o mala mar
        const seaApplies=(e.kind==='session'?e.session_type==='MAR':true)&&(e.boat_type||e.kind==='session'||e.kind==='competition');
        const dayBefore=e.date===addDays(today,1)&&now.slice(11,16)>='20:00'&&now.slice(11,16)<'20:15';
        const threeBefore=hoursTo>2.75&&hoursTo<=3;
        if(F.sea&&seaApplies&&e.date>=today&&(dayBefore||threeBefore)){
          const {c,H}=await wxGet();const r=wxEval(H,e.date,e.event_time,e.end_time,c);
          if(r&&(r.level==='red'||r.level==='amber')){
            const ico=r.level==='red'?'🔴':'🟡',tx=r.level==='red'?'Mala mar':'Precaución';
            await send(techOf(e,e.teams),`${ico} Previsión de mar: ${tx}`,`${e.title} (${dateLabel(e.date,e.event_time)}): ${r.reasons.join(' · ')}. Previsión de modelo, orientativa.`,url(e,e.teams[0]),'training',`cron_sea:${e.kind}:${e.id}:${dayBefore?'d':'h'}`);
            out.weather++;
          }
        }
      }catch(err){out.errors.push(`${e.kind}${e.id}:${String(err.message||err).slice(0,120)}`)}
    }
    return res.status(200).json({ok:true,now,...out});
  }catch(e){return res.status(500).json({error:e?.message||String(e),...out})}
};
