-- Row Training V94 CORREGIDA · SOLO CAMBIOS V94
-- Requiere que V92/V93 ya estén instaladas.
-- IMPORTANTE: training_sessions solo admite GYM, ERG, MAR y DESC.
-- Las sesiones combinadas GYM + ERGO se guardan como DOS filas el mismo día.

begin;

-- ============================================================
-- V94 · PLANIFICACIÓN 2026–27 REVISADA
-- MAR: martes y domingo desde 08/09/2026
-- Jueves: GYM + ERGO conjunto (dos registros: GYM y ERG)
-- Viernes: GYM
-- Sábado: ERGO
-- Tests 2000 m: 29/09, 12/11, 07/01, 25/02, 15/04
-- Regatas: 24/10/2026 y 12/12/2026, sin entrenamiento ese día.
-- Solo se sustituyen sesiones automáticas (created_by is null),
-- salvo que las fechas de regata se limpian por seguridad.
-- ============================================================

-- Días de regata: nunca debe haber entrenamiento.
delete from public.training_sessions
where team_code in ('veteranas','senior_m')
  and session_date in ('2026-10-24','2026-12-12');

-- Quitar planificación automática anterior desde el nuevo patrón.
delete from public.training_sessions
where team_code in ('veteranas','senior_m')
  and session_date between '2026-09-08' and '2027-05-30'
  and created_by is null;

with teams(team_code) as (
  values ('veteranas'),('senior_m')
),
dates as (
  select d::date session_date, extract(isodow from d)::int dow
  from generate_series('2026-09-08'::date,'2027-05-30'::date,'1 day') d
),
calendar as (
  select t.team_code,d.session_date,d.dow,
    case
      when d.session_date in ('2026-10-24','2026-12-12') then 'RACE'
      when d.session_date between '2026-10-19' and '2026-10-25'
        or d.session_date between '2026-12-07' and '2026-12-13' then 'RACEWEEK'
      when d.session_date in ('2026-09-29','2026-11-12','2027-01-07','2027-02-25','2027-04-15') then 'ERGO_TEST'
      when d.session_date in ('2026-09-27','2026-10-11','2026-11-15','2026-11-29') then 'SIM_LONG'
      when d.session_date in ('2027-01-31','2027-02-28','2027-03-28','2027-04-25','2027-05-16') then 'SIM_GENERIC'
      when d.session_date < '2026-10-05' then 'BASE'
      when d.session_date < '2026-10-19' then 'SPEC1'
      when d.session_date < '2026-11-16' then 'BASE2'
      when d.session_date < '2026-12-07' then 'SPEC2'
      when d.session_date < '2027-01-11' then 'RECOVERY'
      when d.session_date < '2027-03-01' then 'DEVELOPMENT'
      when d.session_date < '2027-04-12' then 'SPECIFIC'
      else 'PRECOMP'
    end phase
  from teams t cross join dates d
),
normal_rows as (
  -- MARTES · MAR (excepto test y semana de regata se adapta más abajo)
  select team_code,session_date,'MAR'::text session_type,
    case
      when phase='RACEWEEK' then 'MAR · Activación + salidas · corta'
      when phase='SIM_LONG' then case when team_code='senior_m' then 'MAR · Simulación larga distancia · 4000 m' else 'MAR · Simulación larga distancia · 3000 m' end
      when phase='SIM_GENERIC' then 'MAR · Simulación de regata · distancia configurable'
      when phase='BASE' then 'MAR · Técnica + base aeróbica'
      when phase='BASE2' then 'MAR · Base + técnica'
      when phase='DEVELOPMENT' then 'MAR · Técnica + cambios'
      when phase='SPECIFIC' then 'MAR · Ritmo / viradas / salidas'
      when phase='PRECOMP' then 'MAR · Ritmo competición + salidas'
      else 'MAR · Técnica + ritmo controlado'
    end title,
    case
      when phase='RACEWEEK' then 'CALENTAMIENTO · 12 min\nTÉCNICA · 8–10 min\nSALIDAS · 4×12–15 paladas · recuperación completa\nTRABAJO · 2×3 min vivo sin acumular fatiga\nVUELTA A LA CALMA · 8 min'
      else 'MAR martes. Se deja margen hasta el domingo para recolocar la sesión si el estado del mar impide salir. Duración objetivo 60–75 min según fase.'
    end content
  from calendar
  where dow=2 and phase not in ('RACE','ERGO_TEST')

  union all

  -- JUEVES · GYM conjunto
  select team_code,session_date,'GYM',
    case
      when phase='RACEWEEK' then 'GYM · Activación pre-regata'
      when phase='RECOVERY' then 'GYM · Recuperación / movilidad'
      when phase='DEVELOPMENT' then 'GYM · Fuerza completa'
      when phase='SPECIFIC' then 'GYM · Fuerza específica remo'
      when phase='PRECOMP' then 'GYM · Potencia controlada'
      else 'GYM · Fuerza general'
    end,
    case when phase='RACEWEEK'
      then 'GYM de activación · 25–30 min · RIR 4 · terminar fresco.'
      else 'GYM conjunto. Duración objetivo decidida por el entrenador. Ajustar carga según fase y no llegar al fallo.' end
  from calendar
  where dow=4 and phase not in ('RACE','ERGO_TEST')

  union all

  -- JUEVES · ERGO conjunto
  select team_code,session_date,'ERG',
    case
      when phase='RACEWEEK' then 'ERGO · Activación pre-regata'
      when phase='BASE' then 'ERGO · UT2 conjunto'
      when phase='RECOVERY' then 'ERGO · Suave / técnica'
      when phase='DEVELOPMENT' then 'ERGO · UT1 / AT conjunto'
      when phase='SPECIFIC' then 'ERGO · Umbral conjunto'
      when phase='PRECOMP' then 'ERGO · Ritmo corto conjunto'
      else 'ERGO · Progresivo conjunto'
    end,
    case when phase='RACEWEEK'
      then '12–15 min ERGO suave + 3 aceleraciones breves. Terminar fresco.'
      else 'ERGO conjunto después o junto al GYM. Calentamiento y vuelta a la calma incluidos.' end
  from calendar
  where dow=4 and phase not in ('RACE','ERGO_TEST')

  union all

  -- VIERNES · GYM, excepto semana de regata
  select team_code,session_date,'GYM',
    case
      when phase='BASE' then 'GYM · Fuerza general'
      when phase='RECOVERY' then 'GYM · Recuperación / movilidad'
      when phase='DEVELOPMENT' then 'GYM · Fuerza completa'
      when phase='SPECIFIC' then 'GYM · Fuerza específica remo'
      when phase='PRECOMP' then 'GYM · Potencia controlada'
      else 'GYM · Fuerza equilibrada'
    end,
    'GYM según biblioteca y fase. Mantener técnica perfecta y margen de repeticiones.'
  from calendar
  where dow=5 and phase not in ('RACE','RACEWEEK','ERGO_TEST')

  union all

  -- SÁBADO · ERGO, excepto semana de regata
  select team_code,session_date,'ERG',
    case
      when phase='BASE' then 'ERGO · UT2 progresivo'
      when phase='RECOVERY' then 'ERGO · UT2 suave'
      when phase='DEVELOPMENT' then 'ERGO · UT1 / AT progresivo'
      when phase='SPECIFIC' then 'ERGO · Umbral / ritmo'
      when phase='PRECOMP' then 'ERGO · Ritmo competición corto'
      else 'ERGO · Desarrollo aeróbico'
    end,
    'ERGO según zona de la fase. Calentamiento y vuelta a la calma incluidos. Progresión de fácil a exigente.'
  from calendar
  where dow=6 and phase not in ('RACE','RACEWEEK','ERGO_TEST')

  union all

  -- DOMINGO · MAR, excepto semana de regata
  select team_code,session_date,'MAR',
    case
      when phase='SIM_LONG' then case when team_code='senior_m' then 'MAR · Simulación larga distancia · 4000 m' else 'MAR · Simulación larga distancia · 3000 m' end
      when phase='SIM_GENERIC' then 'MAR · Simulación de regata · distancia configurable'
      when phase='BASE' then 'MAR · Base aeróbica'
      when phase='BASE2' then 'MAR · Base larga + viradas'
      when phase='DEVELOPMENT' then 'MAR · Series + técnica'
      when phase='SPECIFIC' then 'MAR · Series específicas + viradas'
      when phase='PRECOMP' then 'MAR · Simulación parcial / ritmo'
      else 'MAR · Base + técnica'
    end,
    case
      when phase='SIM_LONG' then case when team_code='senior_m'
        then 'CALENTAMIENTO · 15 min\nSALIDAS · 3×15 paladas\nSIMULACIÓN · 4000 m continuos · salida, ritmo, viradas si proceden y cierre final\nOBJETIVO · ejecución y pacing\nVUELTA A LA CALMA · 10 min'
        else 'CALENTAMIENTO · 15 min\nSALIDAS · 3×15 paladas\nSIMULACIÓN · 3000 m continuos · salida, ritmo, viradas si proceden y cierre final\nOBJETIVO · ejecución y pacing\nVUELTA A LA CALMA · 10 min' end
      when phase='SIM_GENERIC' then 'CALENTAMIENTO · 15 min\nSIMULACIÓN DE REGATA · distancia configurable según próxima prueba\nTRABAJO · salida + ritmo sostenido + virada(s) + final\nVUELTA A LA CALMA · 10 min'
      else 'MAR domingo. CALENTAMIENTO · 12–15 min\nTRABAJO MAR · 35–50 min según fase\nIncluir técnica, salidas o viradas según objetivo semanal\nVUELTA A LA CALMA · 8–10 min' end
  from calendar
  where dow=7 and phase not in ('RACE','RACEWEEK','ERGO_TEST')
),
test_rows as (
  -- Cada test se representa correctamente como dos sesiones permitidas: GYM + ERG.
  select team_code,session_date,'GYM'::text session_type,
    'GYM · Activación antes de TEST ERGO 2000 m' title,
    'GYM CONJUNTO · 25–35 min · carga moderada · RIR 3–4 · sin llegar al fallo. Prioridad al test ERGO.' content
  from calendar where phase='ERGO_TEST'
  union all
  select team_code,session_date,'ERG',
    'ERGO · TEST 2000 m' title,
    'TEST ERGO 2000 m · mismo protocolo para comparar evolución\nCALENTAMIENTO · 12–15 min progresivo + 3 aceleraciones\nTEST · 2000 m máximo controlado · registrar tiempo, /500, ppm y RPE\nVUELTA A LA CALMA · 10 min suave\nNOTA · El 29/09 sustituye excepcionalmente el MAR del martes; los siguientes tests coinciden con jueves de GYM + ERGO conjunto.' content
  from calendar where phase='ERGO_TEST'
),
all_rows as (
  select * from normal_rows
  union all
  select * from test_rows
)
insert into public.training_sessions(team_code,session_date,session_type,title,content,created_by)
select r.team_code,r.session_date,r.session_type,r.title,r.content,null
from all_rows r
where r.session_date not in ('2026-10-24','2026-12-12')
  and not exists (
    select 1 from public.training_sessions s
    where s.team_code=r.team_code
      and s.session_date=r.session_date
      and s.session_type=r.session_type
      and coalesce(s.created_by::text,'') <> ''
  );

-- Garantía final de seguridad: regata = cero entrenamientos.
delete from public.training_sessions
where team_code in ('veteranas','senior_m')
  and session_date in ('2026-10-24','2026-12-12');

commit;
