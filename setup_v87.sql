-- Row Training V87 · entrenadores de equipo pueden gestionar altas de SUS equipos
-- Ejecutar UNA VEZ en Supabase > SQL Editor. Es idempotente.
-- Incluye también los ajustes de V86 (biblioteca + reactivación de solicitudes rechazadas).

-- ============================================================
-- A) V86 · Biblioteca editable por entrenadores + reactivación
-- ============================================================
grant select, insert, update, delete on table public.training_library to authenticated;
grant usage, select on sequence public.training_library_id_seq to authenticated;

create or replace function public.can_manage_training_library_v86()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_coach()
    or exists (
      select 1
      from public.team_staff_roles s
      where s.user_id = auth.uid()
        and s.staff_role = 'coach'
    );
$$;

grant execute on function public.can_manage_training_library_v86() to authenticated;

drop policy if exists training_library_coach_insert on public.training_library;
create policy training_library_coach_insert on public.training_library
for insert to authenticated
with check (public.can_manage_training_library_v86());

drop policy if exists training_library_coach_update on public.training_library;
create policy training_library_coach_update on public.training_library
for update to authenticated
using (public.can_manage_training_library_v86())
with check (public.can_manage_training_library_v86());

drop policy if exists training_library_coach_delete on public.training_library;
create policy training_library_coach_delete on public.training_library
for delete to authenticated
using (public.can_manage_training_library_v86());

create or replace function public.reactivate_registration_v86()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sesión no iniciada';
  end if;

  update public.registration_requests
     set status = 'pending',
         assigned_team = null,
         reviewed_by = null,
         reviewed_at = null,
         updated_at = now()
   where user_id = auth.uid()
     and status = 'rejected';
end;
$$;

grant execute on function public.reactivate_registration_v86() to authenticated;

-- ============================================================
-- B) V87 · Altas por entrenadores de equipo
-- ============================================================
-- Entrenador global (user_roles.role='coach') puede gestionar cualquier equipo.
-- Entrenador de equipo solo puede gestionar el/los equipos donde staff_role='coach'.
-- Los ayudantes NO pueden gestionar altas.

create or replace function public.can_manage_registration_v87(p_team text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_coach()
    or (
      p_team is not null
      and exists (
        select 1
        from public.team_staff_roles s
        where s.user_id = auth.uid()
          and s.staff_role = 'coach'
          and s.team_code = p_team
      )
    );
$$;

grant execute on function public.can_manage_registration_v87(text) to authenticated;

-- Política adicional de lectura para entrenadores de equipo.
-- Las solicitudes sin requested_team (enlace general) siguen siendo solo del entrenador global.
drop policy if exists registration_requests_team_coach_read_v81 on public.registration_requests;
drop policy if exists registration_requests_team_coach_read_v87 on public.registration_requests;
create policy registration_requests_team_coach_read_v87
on public.registration_requests
for select to authenticated
using (
  requested_team is not null
  and public.can_manage_registration_v87(requested_team)
);

-- Aprobar y asignar: solo a un equipo que el entrenador puede gestionar.
create or replace function public.approve_registration(p_request_id bigint, p_team_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.registration_requests%rowtype;
  v_global boolean;
begin
  if p_team_code not in ('veteranas','senior_m','senior_f','veteranos_m') then
    raise exception 'Equipo no válido';
  end if;

  v_global := public.is_coach();

  select * into v_req
  from public.registration_requests
  where id = p_request_id
  for update;
  if not found then raise exception 'Solicitud no encontrada'; end if;

  if v_req.status <> 'pending' then
    raise exception 'La solicitud ya no está pendiente';
  end if;

  if not public.can_manage_registration_v87(p_team_code) then
    raise exception 'No tienes permiso para gestionar ese equipo';
  end if;

  -- Solicitud con invitación: el entrenador de equipo debe gestionar el equipo solicitado.
  if v_req.requested_team is not null
     and not public.can_manage_registration_v87(v_req.requested_team) then
    raise exception 'No tienes permiso para gestionar esa solicitud';
  end if;

  -- Solicitudes del enlace general quedan para el entrenador administrador/global.
  if v_req.requested_team is null and not v_global then
    raise exception 'Las solicitudes generales debe gestionarlas el entrenador administrador';
  end if;

  update public.profiles
     set team_code = p_team_code
   where user_id = v_req.user_id;

  update public.registration_requests
     set status = 'approved',
         assigned_team = p_team_code,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         updated_at = now()
   where id = p_request_id;
end;
$$;

grant execute on function public.approve_registration(bigint,text) to authenticated;

-- Rechazar: misma regla; entrenador de equipo solo solicitudes dirigidas a sus equipos.
create or replace function public.reject_registration(p_request_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.registration_requests%rowtype;
  v_global boolean;
begin
  v_global := public.is_coach();

  select * into v_req
  from public.registration_requests
  where id = p_request_id
  for update;
  if not found then raise exception 'Solicitud no encontrada'; end if;

  if v_req.status <> 'pending' then
    raise exception 'La solicitud ya no está pendiente';
  end if;

  if v_req.requested_team is null then
    if not v_global then
      raise exception 'Las solicitudes generales debe gestionarlas el entrenador administrador';
    end if;
  elsif not public.can_manage_registration_v87(v_req.requested_team) then
    raise exception 'No tienes permiso para gestionar esa solicitud';
  end if;

  update public.registration_requests
     set status = 'rejected',
         assigned_team = null,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         updated_at = now()
   where id = p_request_id;
end;
$$;

grant execute on function public.reject_registration(bigint) to authenticated;
