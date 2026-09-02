-- Row Training V97 · CORRECCIÓN TESTS Y MARTES MAR
-- Requiere V96 instalada. Parche idempotente.

begin;

-- 1) Eliminar expresamente los controles antiguos que quedaron en martes 29/09
--    y la antigua fecha 12/11. Se limita a títulos de TEST/activación de test.
delete from public.training_sessions
where team_code in ('veteranas','veteranos_m','senior_m','senior_f')
  and session_date in ('2026-09-29','2026-11-12')
  and (title ilike '%TEST%' or title ilike '%Activación%TEST%' or content ilike '%PROTOCOLO TEST%');

-- 2) Limpiar posibles duplicados de los controles definitivos antes de reconstruirlos.
delete from public.training_sessions
where team_code in ('veteranas','veteranos_m','senior_m','senior_f')
  and session_date in ('2026-10-01','2026-11-19','2027-01-07','2027-02-25','2027-04-15')
  and (title ilike '%TEST%' or title ilike '%Activación%TEST%' or content ilike '%PROTOCOLO TEST%');

-- 3) El martes 29/09 queda como MAR.
insert into public.training_sessions(team_code,session_date,session_type,title,content,created_by)
select t.team_code,'2026-09-29'::date,'MAR','MAR · Técnica + base aeróbica',
  'CALENTAMIENTO · 12 min progresivo\nTÉCNICA · 3 bloques de 6 min centrados en longitud, coordinación y entrada limpia · rec 2 min\nTRABAJO · 3×10 min base aeróbica a ritmo estable · rec 3 min\nFINAL · 4 salidas técnicas de 15 paladas, sin máxima intensidad\nVUELTA A LA CALMA · 8 min suave',
  null
from (values ('veteranas'),('veteranos_m'),('senior_m'),('senior_f')) t(team_code)
where not exists (
  select 1 from public.training_sessions s
  where s.team_code=t.team_code and s.session_date='2026-09-29' and s.session_type='MAR'
);

-- 4) Tests definitivos: jueves conjunto GYM + ERGO.
with test_dates(session_date) as (
  values ('2026-10-01'::date),('2026-11-19'::date),('2027-01-07'::date),('2027-02-25'::date),('2027-04-15'::date)
), teams(team_code,distance_m) as (
  values ('veteranas',1000),('veteranos_m',1000),('senior_m',2000),('senior_f',2000)
)
insert into public.training_sessions(team_code,session_date,session_type,title,content,created_by)
select t.team_code,d.session_date,'ERG',
  '🧪 TEST ERGO '||t.distance_m||' m · CONTROL',
  'PROTOCOLO TEST '||t.distance_m||' m\nCALENTAMIENTO · 12–15 min progresivo\nACTIVACIÓN · 3×20 s a ritmo de test · rec 60–90 s\nDESCANSO · 3 min muy suave antes de iniciar\nTEST · '||t.distance_m||' m máximo controlado\nREGISTRAR · tiempo total, parcial /500, ppm medias, FC si disponible y RPE\nVUELTA A LA CALMA · 10 min UT2 muy suave\nOBJETIVO · repetir el mismo protocolo en todos los controles para comparar evolución.',
  null
from teams t cross join test_dates d;

with test_dates(session_date) as (
  values ('2026-10-01'::date),('2026-11-19'::date),('2027-01-07'::date),('2027-02-25'::date),('2027-04-15'::date)
), teams(team_code,distance_m) as (
  values ('veteranas',1000),('veteranos_m',1000),('senior_m',2000),('senior_f',2000)
)
insert into public.training_sessions(team_code,session_date,session_type,title,content,created_by)
select t.team_code,d.session_date,'GYM',
  'GYM · Activación antes de TEST '||t.distance_m||' m',
  'DURACIÓN · 20–25 min\nOBJETIVO · activar, no fatigar\nMOVILIDAD · 6–8 min\nCORE · 2 ejercicios × 2 series suaves\nPIERNA · 2×8 con carga ligera · RIR 5\nTIRÓN · 2×8 con carga ligera · RIR 5\nEvitar fuerza pesada y llegar fresco al test.',
  null
from teams t cross join test_dates d;

-- 5) Comprobaciones estrictas.
do $$
begin
  if exists (
    select 1 from public.training_sessions
    where team_code in ('veteranas','veteranos_m','senior_m','senior_f')
      and session_date='2026-09-29'
      and (title ilike '%TEST%' or content ilike '%PROTOCOLO TEST%')
  ) then raise exception 'V97: todavía existe un TEST el martes 29/09'; end if;

  if exists (
    select 1 from public.training_sessions
    where title ilike '%TEST ERGO%'
      and ((team_code in ('veteranas','veteranos_m') and title not ilike '%1000%')
        or (team_code in ('senior_m','senior_f') and title not ilike '%2000%'))
  ) then raise exception 'V97: distancia de TEST incorrecta para la categoría'; end if;
end $$;

commit;
