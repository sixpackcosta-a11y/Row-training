-- Row Training V103 · edición y comparación de perfiles de remeros
-- Ejecutar en Supabase SQL Editor antes de publicar V103.

begin;

-- Fecha de nacimiento persistente para poder mostrar la edad correctamente.
alter table public.profiles
  add column if not exists birth_date date;

grant select, update on public.profiles to authenticated;
grant select, insert on public.athlete_metrics to authenticated;

-- Entrenadores/ayudantes autorizados para ese remero pueden editar sus datos básicos.
drop policy if exists profiles_staff_update_v103 on public.profiles;
create policy profiles_staff_update_v103 on public.profiles
for update to authenticated
using (auth.uid() = user_id or public.can_record_athlete_v72(user_id))
with check (auth.uid() = user_id or public.can_record_athlete_v72(user_id));

-- Las métricas se guardan como histórico: cada edición crea una nueva medición.
drop policy if exists athlete_metrics_staff_insert_v103 on public.athlete_metrics;
create policy athlete_metrics_staff_insert_v103 on public.athlete_metrics
for insert to authenticated
with check (auth.uid() = user_id or public.can_record_athlete_v72(user_id));



-- Estado de conexión Concept2/ErgData para entrenadores, sin exponer tokens OAuth.
create or replace function public.concept2_connection_status_v103()
returns table(
  user_id uuid,
  connected boolean,
  concept2_username text,
  last_sync_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select p.user_id,
         (c.user_id is not null) as connected,
         c.concept2_username,
         c.last_sync_at
  from public.profiles p
  left join public.concept2_connections c on c.user_id = p.user_id
  where auth.uid() = p.user_id
     or public.can_record_athlete_v72(p.user_id)
     or public.is_coach();
$$;
revoke all on function public.concept2_connection_status_v103() from public;
grant execute on function public.concept2_connection_status_v103() to authenticated;

commit;

-- Comprobación rápida.
select column_name
from information_schema.columns
where table_schema='public' and table_name='profiles' and column_name='birth_date';
