-- Row Training V96 · ESTABILIDAD + TESTS POR CATEGORÍA + MES DEL REMERO
-- Requiere V95 instalada. Parche idempotente.

begin;

-- Fechas definitivas de control: jueves, coincidiendo con GYM + ERGO conjunto.
-- 01/10/2026, 19/11/2026, 07/01/2027, 25/02/2027, 15/04/2027.

-- 1) Eliminar tests automáticos anteriores y cualquier sesión automática que choque con los nuevos tests.
delete from public.training_sessions
where team_code in ('veteranas','veteranos_m','senior_m','senior_f')
  and created_by is null
  and (
    title ilike '%TEST ERGO%'
    or session_date in ('2026-10-01','2026-11-19','2027-01-07','2027-02-25','2027-04-15')
  );

-- 2) Recuperar el martes 29/09 como MAR para los equipos que ya tienen la planificación principal.
insert into public.training_sessions(team_code,session_date,session_type,title,content,created_by)
select t.team_code,'2026-09-29'::date,'MAR','MAR · Técnica + base aeróbica',
  'CALENTAMIENTO · 12 min progresivo\nTÉCNICA · 3 bloques de 6 min centrados en longitud, coordinación y entrada limpia · rec 2 min\nTRABAJO · 3×10 min base aeróbica a ritmo estable · rec 3 min\nFINAL · 4 salidas técnicas de 15 paladas, sin máxima intensidad\nVUELTA A LA CALMA · 8 min suave',
  null
from (values ('veteranas'),('senior_m')) t(team_code)
where not exists (
  select 1 from public.training_sessions s
  where s.team_code=t.team_code and s.session_date='2026-09-29' and s.session_type='MAR'
);

-- 3) Crear tests correctos por categoría.
with test_dates(session_date) as (
  values ('2026-10-01'::date),('2026-11-19'::date),('2027-01-07'::date),('2027-02-25'::date),('2027-04-15'::date)
), teams(team_code,distance_m) as (
  values
    ('veteranas',1000),
    ('veteranos_m',1000),
    ('senior_m',2000),
    ('senior_f',2000)
)
insert into public.training_sessions(team_code,session_date,session_type,title,content,created_by)
select t.team_code,d.session_date,'ERG',
  '🧪 TEST ERGO '||t.distance_m||' m · CONTROL',
  'PROTOCOLO TEST '||t.distance_m||' m\nCALENTAMIENTO · 12–15 min progresivo\nACTIVACIÓN · 3×20 s a ritmo de test · rec 60–90 s\nDESCANSO · 3 min muy suave antes de iniciar\nTEST · '||t.distance_m||' m máximo controlado\nREGISTRAR · tiempo total, parcial /500, ppm medias, FC si disponible y RPE\nVUELTA A LA CALMA · 10 min UT2 muy suave\nOBJETIVO · repetir el mismo protocolo en todos los controles para comparar evolución.',
  null
from teams t cross join test_dates d;

-- 4) Activación GYM ligera el mismo jueves del test.
with test_dates(session_date) as (
  values ('2026-10-01'::date),('2026-11-19'::date),('2027-01-07'::date),('2027-02-25'::date),('2027-04-15'::date)
), teams(team_code,distance_m) as (
  values
    ('veteranas',1000),
    ('veteranos_m',1000),
    ('senior_m',2000),
    ('senior_f',2000)
)
insert into public.training_sessions(team_code,session_date,session_type,title,content,created_by)
select t.team_code,d.session_date,'GYM',
  'GYM · Activación antes de TEST '||t.distance_m||' m',
  'DURACIÓN · 20–25 min\nOBJETIVO · activar, no fatigar\nMOVILIDAD · 6–8 min\nCORE · 2 ejercicios × 2 series suaves\nPIERNA · 2×8 con carga ligera · RIR 5\nTIRÓN · 2×8 con carga ligera · RIR 5\nEvitar fuerza pesada y llegar fresco al test.',
  null
from teams t cross join test_dates d;

-- 5) Seguridad: no permitir 2000 m en veteranos ni 1000 m en senior en tests automáticos.
do $$
begin
  if exists (
    select 1 from public.training_sessions
    where created_by is null and title ilike '%TEST ERGO%'
      and ((team_code in ('veteranas','veteranos_m') and title ilike '%2000%')
        or (team_code in ('senior_m','senior_f') and title ilike '%1000%'))
  ) then
    raise exception 'V96: distancia de TEST incorrecta para la categoría';
  end if;
end $$;

commit;
