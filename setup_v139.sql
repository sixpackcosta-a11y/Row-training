-- Row Training V139 · MAR visible para remeros sin revelar la planificación.

begin;

create or replace function public.athlete_mar_sessions_v139(
  p_team text,
  p_start date,
  p_end date
)
returns table (
  id bigint,
  team_code text,
  session_date date,
  session_type text,
  title text,
  content text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select
    s.id,
    s.team_code,
    s.session_date,
    'MAR'::text as session_type,
    'MAR · Sesión de mar'::text as title,
    null::text as content,
    s.created_at
  from public.training_sessions s
  where s.team_code=p_team
    and s.session_type='MAR'
    and s.session_date between p_start and p_end
    and (
      exists (
        select 1
        from public.rower_team_memberships m
        where m.user_id=auth.uid()
          and m.team_code=p_team
          and m.is_rower=true
      )
      or exists (
        select 1
        from public.profiles p
        where p.user_id=auth.uid()
          and p.team_code=p_team
      )
    )
  order by s.session_date,s.created_at;
$$;

revoke all on function public.athlete_mar_sessions_v139(text,date,date) from public;
grant execute on function public.athlete_mar_sessions_v139(text,date,date) to authenticated;

commit;

-- Debe devolver solo fecha y el texto genérico; content siempre será null.
select routine_name
from information_schema.routines
where routine_schema='public'
  and routine_name='athlete_mar_sessions_v139';
