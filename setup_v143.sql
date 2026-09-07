-- V143 · fechas separadas, recuperación de asociaciones inequívocas y
-- exclusión reversible de parciales Concept2. No modifica planificación.
alter table public.concept2_results
  add column if not exists excluded_splits integer[] not null default '{}';

alter table public.workout_logs
  add column if not exists performed_at timestamptz;

update public.workout_logs
set performed_at=coalesce(performed_at,created_at)
where performed_at is null;

create or replace function public.set_workout_performed_at_v143()
returns trigger language plpgsql as $$
begin
  if new.performed_at is null then new.performed_at=now(); end if;
  return new;
end $$;
drop trigger if exists workout_performed_at_v143 on public.workout_logs;
create trigger workout_performed_at_v143 before insert on public.workout_logs
for each row execute function public.set_workout_performed_at_v143();

-- Recupera solo asociaciones antiguas con una única sesión posible: mismo
-- tipo, misma fecha planificada, mismo título y equipo al que pertenece.
with candidates as (
  select w.id as workout_id,min(s.id) as session_id,count(*) as matches
  from public.workout_logs w
  join public.training_sessions s
    on s.session_date=w.session_date
   and lower(s.session_type)=case when lower(w.session_type) in ('erg','ergo') then 'erg' else lower(w.session_type) end
   and lower(trim(s.title))=lower(trim(w.session_code))
  where w.training_session_id is null
    and exists (
      select 1 from public.rower_team_memberships m
      where m.user_id=w.user_id and m.team_code=s.team_code and m.is_rower=true
    )
  group by w.id
)
update public.workout_logs w
set training_session_id=c.session_id
from candidates c
where w.id=c.workout_id and c.matches=1;

grant select,update on table public.concept2_results to service_role;
grant select,update on table public.workout_logs to service_role;
