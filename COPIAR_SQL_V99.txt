-- Row Training V99 · DETALLE REAL GYM / ERGO PARA REMEROS
-- Corrige sesiones automáticas ya existentes que quedaron con contenido genérico.
-- No modifica sesiones creadas manualmente por entrenadores (created_by IS NOT NULL).

begin;

-- 1) ERGO automático: sustituir textos genéricos por prescripción completa según fase.
with src as (
  select id, session_date,
    case
      when session_date between '2026-10-19' and '2026-10-25' or session_date between '2026-12-07' and '2026-12-13' then 'RACEWEEK'
      when session_date < '2026-10-05' then 'BASE'
      when session_date < '2026-10-19' then 'SPEC1'
      when session_date < '2026-11-16' then 'BASE2'
      when session_date < '2026-12-07' then 'SPEC2'
      when session_date < '2027-01-11' then 'RECOVERY'
      when session_date < '2027-03-01' then 'DEVELOPMENT'
      when session_date < '2027-04-12' then 'SPECIFIC'
      else 'PRECOMP'
    end phase,
    extract(isodow from session_date)::int dow
  from public.training_sessions
  where team_code in ('veteranas','senior_m')
    and session_date between '2026-09-01' and '2027-05-31'
    and session_type='ERG'
    and created_by is null
    and title not ilike '%TEST%'
)
update public.training_sessions s
set title = case
    when src.phase='RACEWEEK' then 'ERGO · Activación pre-regata'
    when src.dow=4 and src.phase='BASE' then 'ERGO · UT2 conjunto · 3×12 min'
    when src.dow=4 and src.phase='SPEC1' then 'ERGO · UT1 controlado · 4×8 min'
    when src.dow=4 and src.phase='BASE2' then 'ERGO · UT2/UT1 · 3×15 min'
    when src.dow=4 and src.phase='SPEC2' then 'ERGO · AT · 5×5 min'
    when src.dow=4 and src.phase='RECOVERY' then 'ERGO · UT2 suave · 2×15 min'
    when src.dow=4 and src.phase='DEVELOPMENT' then 'ERGO · UT1/AT · 4×10 min'
    when src.dow=4 and src.phase='SPECIFIC' then 'ERGO · Umbral · 5×6 min'
    when src.dow=4 then 'ERGO · Ritmo competición · 8×2 min'
    when src.dow=6 and src.phase='BASE' then 'ERGO · UT2 largo · 2×20 min'
    when src.dow=6 and src.phase='SPEC1' then 'ERGO · Progresivo · 3×10 min'
    when src.dow=6 and src.phase='BASE2' then 'ERGO · UT2 largo · 3×15 min'
    when src.dow=6 and src.phase='SPEC2' then 'ERGO · AT corto · 6×4 min'
    when src.dow=6 and src.phase='RECOVERY' then 'ERGO · Recuperación · 30 min continuo'
    when src.dow=6 and src.phase='DEVELOPMENT' then 'ERGO · UT1 progresivo · 3×12 min'
    when src.dow=6 and src.phase='SPECIFIC' then 'ERGO · Ritmo específico · 6×3 min'
    when src.dow=6 then 'ERGO · Velocidad / ritmo · 10×1 min'
    else coalesce(s.title,'ERGO') end,
  content = case
    when src.phase='RACEWEEK' then E'CALENTAMIENTO · 10 min UT2 @18–20 ppm\nTRABAJO · 3×1 min vivo @28–30 ppm · rec 2 min muy suave\nOBJETIVO · activar sin acumular fatiga\nVUELTA A LA CALMA · 8 min\nRPE · 4–5/10'
    when src.dow=4 and src.phase='BASE' then E'CALENTAMIENTO · 10 min progresivo @18–20 ppm\nTRABAJO · 3×12 min UT2 @20 ppm · rec 3 min suave\nFOCO · longitud de palada y ritmo estable\nVUELTA A LA CALMA · 8 min\nRPE · 4–5/10'
    when src.dow=4 and src.phase='SPEC1' then E'CALENTAMIENTO · 12 min + 3×20 s progresivos\nTRABAJO · 4×8 min UT1 @22–24 ppm · rec 3 min\nOBJETIVO · potencia aeróbica controlada\nVUELTA A LA CALMA · 8 min\nRPE · 6/10'
    when src.dow=4 and src.phase='BASE2' then E'CALENTAMIENTO · 10 min\nTRABAJO · 3×15 min: 10 min UT2 @20–22 + 5 min UT1 @23–24 · rec 3 min\nVUELTA A LA CALMA · 8 min\nRPE · 5–6/10'
    when src.dow=4 and src.phase='SPEC2' then E'CALENTAMIENTO · 12 min + 3 aceleraciones\nTRABAJO · 5×5 min AT @25–27 ppm · rec 3 min\nFOCO · sostener el umbral sin perder técnica\nVUELTA A LA CALMA · 10 min\nRPE · 7–8/10'
    when src.dow=4 and src.phase='RECOVERY' then E'CALENTAMIENTO · 8 min\nTRABAJO · 2×15 min UT2 @18–20 ppm · rec 3 min\nOBJETIVO · recuperación activa + técnica\nVUELTA A LA CALMA · 8 min\nRPE · 3–4/10'
    when src.dow=4 and src.phase='DEVELOPMENT' then E'CALENTAMIENTO · 12 min\nTRABAJO · 4×10 min: 7 min UT1 @22–24 + 3 min AT @25–26 · rec 3 min\nVUELTA A LA CALMA · 10 min\nRPE · 6–7/10'
    when src.dow=4 and src.phase='SPECIFIC' then E'CALENTAMIENTO · 12–15 min + 3×20 s\nTRABAJO · 5×6 min AT/umbral @26–28 ppm · rec 3 min\nÚLTIMA SERIE · progresiva solo si se mantiene técnica\nVUELTA A LA CALMA · 10 min\nRPE · 7–8/10'
    when src.dow=4 then E'CALENTAMIENTO · 12–15 min\nTRABAJO · 8×2 min ritmo competición @30–34 ppm · rec 2 min\nFOCO · salida controlada, ritmo y cierre\nVUELTA A LA CALMA · 10 min\nRPE · 8/10'
    when src.dow=6 and src.phase='BASE' then E'CALENTAMIENTO · 10 min\nTRABAJO · 2×20 min UT2 @20–22 ppm · rec 4 min\nVUELTA A LA CALMA · 8 min\nRPE · 4–5/10'
    when src.dow=6 and src.phase='SPEC1' then E'CALENTAMIENTO · 10 min\nTRABAJO · 3×10 min: 6 min UT2 + 4 min UT1 · rec 3 min\nPPM · 20→24\nVUELTA A LA CALMA · 8 min\nRPE · 5–6/10'
    when src.dow=6 and src.phase='BASE2' then E'CALENTAMIENTO · 10 min\nTRABAJO · 3×15 min UT2 @20–22 ppm · rec 3 min\nPROGRESIÓN · últimos 3 min de cada bloque a UT1 si hay buenas sensaciones\nVUELTA A LA CALMA · 8 min'
    when src.dow=6 and src.phase='SPEC2' then E'CALENTAMIENTO · 12 min\nTRABAJO · 6×4 min AT @26–28 ppm · rec 2:30 min\nVUELTA A LA CALMA · 10 min\nRPE · 7–8/10'
    when src.dow=6 and src.phase='RECOVERY' then E'TRABAJO · 30 min continuo UT2 muy cómodo @18–20 ppm\nTÉCNICA · cada 10 min, 10 paladas algo más vivas\nRPE · 3/10'
    when src.dow=6 and src.phase='DEVELOPMENT' then E'CALENTAMIENTO · 10 min\nTRABAJO · 3×12 min UT1 @22–24 ppm · rec 3 min\nÚLTIMO BLOQUE · progresivo\nVUELTA A LA CALMA · 8 min'
    when src.dow=6 and src.phase='SPECIFIC' then E'CALENTAMIENTO · 12 min\nTRABAJO · 6×3 min @28–30 ppm · rec 3 min\nOBJETIVO · ritmo alto con técnica estable\nVUELTA A LA CALMA · 10 min'
    when src.dow=6 then E'CALENTAMIENTO · 12 min\nTRABAJO · 10×1 min @32–36 ppm · rec 1:30 min\nFOCO · no sacrificar técnica por cadencia\nVUELTA A LA CALMA · 10 min'
    else s.content end
from src where s.id=src.id;

-- 2) GYM automático: prescripción concreta, no texto genérico.
with src as (
  select id, session_date,
    case
      when session_date between '2026-10-19' and '2026-10-25' or session_date between '2026-12-07' and '2026-12-13' then 'RACEWEEK'
      when session_date < '2026-10-05' then 'BASE'
      when session_date < '2026-10-19' then 'SPEC1'
      when session_date < '2026-11-16' then 'BASE2'
      when session_date < '2026-12-07' then 'SPEC2'
      when session_date < '2027-01-11' then 'RECOVERY'
      when session_date < '2027-03-01' then 'DEVELOPMENT'
      when session_date < '2027-04-12' then 'SPECIFIC'
      else 'PRECOMP'
    end phase,
    extract(isodow from session_date)::int dow
  from public.training_sessions
  where team_code in ('veteranas','senior_m')
    and session_date between '2026-09-01' and '2027-05-31'
    and session_type='GYM'
    and created_by is null
    and title not ilike '%TEST%'
)
update public.training_sessions s
set title = case
    when src.phase='RACEWEEK' then 'GYM · Activación pre-regata · 30 min'
    when src.phase='RECOVERY' then 'GYM · Recuperación + movilidad · 35 min'
    when src.phase='DEVELOPMENT' then 'GYM · Fuerza completa · 55–60 min'
    when src.phase='SPECIFIC' then 'GYM · Fuerza específica remo · 50–55 min'
    when src.phase='PRECOMP' then 'GYM · Potencia controlada · 45–50 min'
    when src.dow=4 then 'GYM · Fuerza general A · 55–60 min'
    else 'GYM · Fuerza general B · 45–50 min' end,
  content = case
    when src.phase='RACEWEEK' then E'CALENTAMIENTO · 8 min movilidad + activación\nPrensa de piernas · 2×8 · rec 90 s · RIR 4\nRemo sentado en polea · 2×8 · rec 75 s · RIR 4\nPress de pecho · 2×8 · rec 75 s · RIR 4\nPallof press · 2×8/lado · rec 45 s\nVUELTA A LA CALMA · 5 min\nOBJETIVO · salir fresco, sin agujetas'
    when src.phase='RECOVERY' then E'CALENTAMIENTO · 8 min suave\nGoblet squat ligera · 2×10 · rec 60 s\nRemo sentado en polea · 2×12 · rec 60 s\nHip thrust · 2×10 · rec 75 s\nPallof press · 2×10/lado · rec 45 s\nMovilidad cadera/torácica · 8–10 min\nRIR · 4–5'
    when src.phase='DEVELOPMENT' then E'CALENTAMIENTO · 10 min\nPrensa de piernas · 4×8 · rec 2 min · RIR 2\nPeso muerto rumano · 3×8 · rec 90 s · RIR 2\nRemo sentado en polea · 4×8 · rec 90 s\nPress de pecho · 3×8 · rec 90 s\nPallof press · 3×10/lado · rec 45–60 s\nFarmer carry · 3×30–40 m · rec 60 s\nVUELTA A LA CALMA · 5 min'
    when src.phase='SPECIFIC' then E'CALENTAMIENTO · 10 min\nPrensa de piernas · 4×6 · rec 2–3 min · RIR 2\nPeso muerto rumano · 3×6 · rec 2 min · RIR 2\nRemo sentado en polea · 4×6–8 · rec 90 s\nJalón al pecho · 3×8 · rec 90 s\nPallof press · 3×8/lado · rec 45 s\nFarmer carry · 3×30 m pesado · rec 75 s\nVUELTA A LA CALMA · 5 min'
    when src.phase='PRECOMP' then E'CALENTAMIENTO · 10 min\nPrensa de piernas · 3×5 explosivas · rec 2–3 min · RIR 3\nHip thrust · 3×6 · rec 2 min\nRemo sentado en polea · 3×6 · rec 90 s\nPress de pecho · 2×6 · rec 90 s\nPallof press · 2×8/lado\nSaltos al cajón · 3×4 · rec completa\nOBJETIVO · velocidad, no fatiga'
    when src.dow=4 then E'CALENTAMIENTO · 10 min movilidad + activación\nPrensa de piernas · 3×10 · rec 2 min · RIR 2–3\nPeso muerto rumano · 3×10 · rec 90 s · RIR 2–3\nRemo sentado en polea · 3×10 · rec 75–90 s\nPress de pecho · 3×10 · rec 90 s\nPallof press · 3×10/lado · rec 45 s\nPlancha frontal · 3×30–40 s · rec 45 s\nVUELTA A LA CALMA · 5 min'
    else E'CALENTAMIENTO · 8 min\nZancada atrás · 3×8/lado · rec 75 s\nHip thrust · 3×10 · rec 90 s\nJalón al pecho · 3×10 · rec 75 s\nPress de hombro · 3×8–10 · rec 75 s\nFarmer carry · 3×30 m · rec 60 s\nPlancha lateral · 2×30 s/lado · rec 45 s\nVUELTA A LA CALMA · 5 min' end
from src where s.id=src.id;

-- 3) Activación específica en día de TEST, con distancia correcta por categoría.
update public.training_sessions
set title = case when team_code in ('veteranas','veteranos_m') then 'GYM · Activación antes de TEST 1000 m' else 'GYM · Activación antes de TEST 2000 m' end,
    content = E'CALENTAMIENTO · 8 min movilidad + activación\nPrensa ligera · 2×6 · RIR 5\nRemo sentado ligero · 2×6 · RIR 5\nPallof press · 2×8/lado\nDESCANSO · dejar 10–15 min antes del calentamiento específico de ERGO\nOBJETIVO · activar sin fatigar'
where session_type='GYM' and created_by is null and title ilike '%TEST%';

-- 4) Seguridad: ningún ERGO/GYM automático de los equipos planificados queda genérico o vacío.
do $$
begin
  if exists (
    select 1 from public.training_sessions
    where team_code in ('veteranas','senior_m')
      and session_date between '2026-09-01' and '2027-05-31'
      and session_type in ('GYM','ERG')
      and created_by is null
      and title not ilike '%TEST%'
      and (content is null or length(trim(content)) < 60)
  ) then
    raise exception 'V99: queda alguna sesión automática GYM/ERGO sin detalle suficiente';
  end if;
end $$;

commit;
