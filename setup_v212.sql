-- Row Training V212
-- Conserva automáticamente el equipo solicitado desde el enlace de inscripción.
-- No crea una pertenencia activa ni da acceso antes de la aprobación del entrenador.

create or replace function public.v212_fill_registration_requested_team()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_team text;
begin
  if new.user_id is null then
    return new;
  end if;

  if nullif(btrim(coalesce(new.requested_team,'')), '') is null then
    select nullif(btrim(coalesce(u.raw_user_meta_data ->> 'requested_team','')), '')
      into v_team
      from auth.users u
     where u.id = new.user_id;

    if v_team is not null
       and exists (
         select 1 from public.rowing_teams t
          where t.code = v_team and coalesce(t.is_active,true) = true
       ) then
      new.requested_team := v_team;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_v212_registration_requested_team on public.registration_requests;
create trigger trg_v212_registration_requested_team
before insert or update of user_id, requested_team
on public.registration_requests
for each row
execute function public.v212_fill_registration_requested_team();

-- Backfill seguro para solicitudes pendientes que todavía no tengan equipo,
-- usando únicamente el equipo que llegó en el enlace y quedó guardado en Auth metadata.
update public.registration_requests r
   set requested_team = u.raw_user_meta_data ->> 'requested_team'
  from auth.users u
 where r.user_id = u.id
   and lower(coalesce(r.status,'')) = 'pending'
   and nullif(btrim(coalesce(r.requested_team,'')), '') is null
   and nullif(btrim(coalesce(u.raw_user_meta_data ->> 'requested_team','')), '') is not null
   and exists (
     select 1 from public.rowing_teams t
      where t.code = (u.raw_user_meta_data ->> 'requested_team')
        and coalesce(t.is_active,true) = true
   );
