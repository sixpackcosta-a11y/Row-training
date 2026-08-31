-- Row Training V42 · equipo del remero + permisos de asignación
-- Ejecutar una sola vez después de V39/V40/V41.

alter table public.profiles
  add column if not exists team_code text;

-- Limita los valores válidos sin romper instalaciones previas.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='profiles_team_code_check'
      and conrelid='public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_team_code_check
      check (team_code is null or team_code in ('veteranas','senior_m','senior_f','veteranos_m'));
  end if;
end $$;

grant select,update on public.profiles to authenticated;

-- Un entrenador puede asignar equipo a remeros desde el panel.
drop policy if exists profiles_coach_update on public.profiles;
create policy profiles_coach_update on public.profiles
for update to authenticated
using (public.is_coach())
with check (public.is_coach());

-- Comprobación: la consulta debe devolver la columna team_code.
select user_id, full_name, team_code
from public.profiles
order by full_name nulls last;
