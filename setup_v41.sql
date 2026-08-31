-- Row Training V41 · copiar planificación base por categoría
-- Ejecutar DESPUÉS de setup_v39.sql y setup_v40.sql.
-- La copia es independiente: los cambios posteriores en un equipo NO modifican los demás.

-- 1) Veteranas -> Veteranos masculino
insert into public.training_sessions(team_code, session_date, session_type, title, content, created_by)
select 'veteranos_m', s.session_date, s.session_type, s.title, s.content, auth.uid()
from public.training_sessions s
where s.team_code = 'veteranas'
  and s.session_date between date '2026-09-01' and date '2027-05-31'
  and not exists (
    select 1 from public.training_sessions t
    where t.team_code = 'veteranos_m'
      and t.session_date = s.session_date
      and t.session_type = s.session_type
  );

-- 2) Senior masculino -> Senior femenino
insert into public.training_sessions(team_code, session_date, session_type, title, content, created_by)
select 'senior_f', s.session_date, s.session_type, s.title, s.content, auth.uid()
from public.training_sessions s
where s.team_code = 'senior_m'
  and s.session_date between date '2026-09-01' and date '2027-05-31'
  and not exists (
    select 1 from public.training_sessions t
    where t.team_code = 'senior_f'
      and t.session_date = s.session_date
      and t.session_type = s.session_type
  );

-- 3) Actualizar la descripción de CONTROL para reflejar ambas categorías.
update public.exercise_library
set description = 'Control específico según categoría: 1000 m Veteran@s / 2000 m Senior.',
    default_dose = '1 test',
    updated_at = now()
where category = 'ERG' and name = 'CONTROL';

-- Comprobación rápida: debe devolver cuatro equipos con sesiones.
select team_code, count(*) as sesiones
from public.training_sessions
where session_date between date '2026-09-01' and date '2027-05-31'
group by team_code
order by team_code;
