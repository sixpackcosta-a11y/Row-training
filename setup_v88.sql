-- Row Training V88 · equipos dinámicos + biblioteca compartida + multimedia GYM
-- Ejecutar UNA VEZ en Supabase > SQL Editor. Es idempotente.
-- Incluye y sustituye los ajustes SQL de V86/V87 necesarios para esta versión.

-- ============================================================
-- 1) EQUIPOS DINÁMICOS (tabla propia de Row Training; no toca public.teams existente)
-- ============================================================
create table if not exists public.rowing_teams (
  code text primary key,
  name text not null,
  category text,
  gender text,
  is_active boolean not null default true,
  sort_order integer not null default 100,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.rowing_teams(code,name,category,gender,sort_order) values
 ('veteranas','Veteranas femenino','Veteranas','Femenino',10),
 ('senior_m','Senior masculino','Senior','Masculino',20),
 ('senior_f','Senior femenino','Senior','Femenino',30),
 ('veteranos_m','Veteranos masculino','Veteranos','Masculino',40)
on conflict(code) do update set
 name=excluded.name,
 category=coalesce(public.rowing_teams.category,excluded.category),
 gender=coalesce(public.rowing_teams.gender,excluded.gender),
 sort_order=least(public.rowing_teams.sort_order,excluded.sort_order);

alter table public.rowing_teams enable row level security;
grant select on public.rowing_teams to anon, authenticated;
grant insert,update,delete on public.rowing_teams to authenticated;

drop policy if exists teams_public_read_v88 on public.rowing_teams;
create policy teams_public_read_v88 on public.rowing_teams
for select to anon, authenticated using (is_active or auth.role()='authenticated');

drop policy if exists teams_admin_write_v88 on public.rowing_teams;
create policy teams_admin_write_v88 on public.rowing_teams
for all to authenticated
using (public.is_coach())
with check (public.is_coach());

-- Quita únicamente restricciones CHECK que fijaban la lista antigua de equipos.
do $$
declare r record;
begin
  for r in
    select conrelid::regclass as tbl, conname
    from pg_constraint
    where contype='c'
      and conrelid in (
        'public.profiles'::regclass,
        'public.coach_team_access'::regclass,
        'public.training_sessions'::regclass,
        'public.registration_requests'::regclass,
        'public.team_staff_roles'::regclass
      )
      and (
        pg_get_constraintdef(oid) ilike '%team_code%'
        or pg_get_constraintdef(oid) ilike '%requested_team%'
        or pg_get_constraintdef(oid) ilike '%assigned_team%'
      )
  loop
    execute format('alter table %s drop constraint if exists %I',r.tbl,r.conname);
  end loop;
end $$;

-- Conserva la integridad del tipo de rol aunque se haya eliminado un CHECK combinado antiguo.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.team_staff_roles'::regclass
      and conname='team_staff_roles_staff_role_v88'
  ) then
    alter table public.team_staff_roles
      add constraint team_staff_roles_staff_role_v88
      check (staff_role in ('coach','assistant'));
  end if;
end $$;

-- ============================================================
-- 2) BIBLIOTECA COMPARTIDA / ARCHIVADO / PREFERENCIAS
-- ============================================================
alter table public.training_library
  add column if not exists is_system boolean not null default false,
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid references auth.users(id) on delete set null,
  add column if not exists created_by_name text,
  add column if not exists image_url text,
  add column if not exists how_url text,
  add column if not exists video_url text,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

-- Los registros históricos sin autor procedían de plantillas base instaladas por SQL.
update public.training_library
set is_system=true
where created_by is null and is_system=false;

grant select,insert,update on public.training_library to authenticated;
grant usage,select on sequence public.training_library_id_seq to authenticated;
revoke delete on public.training_library from authenticated;

create or replace function public.can_create_training_library_v88()
returns boolean language sql stable security definer set search_path=public as $$
  select public.is_coach()
      or exists(select 1 from public.team_staff_roles s where s.user_id=auth.uid() and s.staff_role='coach')
$$;
grant execute on function public.can_create_training_library_v88() to authenticated;

create or replace function public.can_edit_training_library_v88(p_created_by uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.is_coach() or p_created_by=auth.uid()
$$;
grant execute on function public.can_edit_training_library_v88(uuid) to authenticated;

drop policy if exists training_library_coach_insert on public.training_library;
create policy training_library_coach_insert on public.training_library
for insert to authenticated
with check (public.can_create_training_library_v88() and created_by=auth.uid());

drop policy if exists training_library_coach_update on public.training_library;
create policy training_library_coach_update on public.training_library
for update to authenticated
using (public.can_edit_training_library_v88(created_by))
with check (public.can_edit_training_library_v88(created_by));

drop policy if exists training_library_coach_delete on public.training_library;

drop policy if exists training_library_shared_read_v88 on public.training_library;
create policy training_library_shared_read_v88 on public.training_library
for select to authenticated
using (is_active or public.can_create_training_library_v88());


create table if not exists public.training_library_user_prefs (
  user_id uuid not null references auth.users(id) on delete cascade,
  library_id bigint not null references public.training_library(id) on delete cascade,
  is_hidden boolean not null default false,
  is_favorite boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key(user_id,library_id)
);
alter table public.training_library_user_prefs enable row level security;
grant select,insert,update,delete on public.training_library_user_prefs to authenticated;
drop policy if exists training_library_prefs_own_v88 on public.training_library_user_prefs;
create policy training_library_prefs_own_v88 on public.training_library_user_prefs
for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

-- Multimedia de ejercicios GYM. Público para lectura; solo entrenadores pueden escribir.
insert into storage.buckets(id,name,public)
values('gym-media','gym-media',true)
on conflict(id) do update set public=true;

drop policy if exists gym_media_public_read_v88 on storage.objects;
create policy gym_media_public_read_v88 on storage.objects
for select to public using(bucket_id='gym-media');

drop policy if exists gym_media_coach_insert_v88 on storage.objects;
create policy gym_media_coach_insert_v88 on storage.objects
for insert to authenticated
with check(bucket_id='gym-media' and public.can_create_training_library_v88());

drop policy if exists gym_media_coach_update_v88 on storage.objects;
create policy gym_media_coach_update_v88 on storage.objects
for update to authenticated
using(bucket_id='gym-media' and public.can_create_training_library_v88())
with check(bucket_id='gym-media' and public.can_create_training_library_v88());

drop policy if exists gym_media_coach_delete_v88 on storage.objects;
create policy gym_media_coach_delete_v88 on storage.objects
for delete to authenticated
using(bucket_id='gym-media' and public.can_create_training_library_v88());

-- ============================================================
-- 3) ERGO: EQUIPOS Y FASES MULTISELECCIÓN
-- ============================================================
alter table public.ergo_library
  add column if not exists team_codes text[] not null default '{}',
  add column if not exists phase_codes text[] not null default '{}';

update public.ergo_library
set team_codes = case
  when teams='both' then '{}'::text[]
  when teams='veterans' then array['veteranas','veteranos_m']::text[]
  when teams='senior' then array['senior_m','senior_f']::text[]
  else array[teams]::text[] end
where coalesce(array_length(team_codes,1),0)=0 and teams<>'both';

update public.ergo_library
set phase_codes = string_to_array(phases,',')
where coalesce(array_length(phase_codes,1),0)=0 and coalesce(phases,'')<>'';

grant select,insert,update on public.ergo_library to authenticated;
revoke delete on public.ergo_library from authenticated;
drop policy if exists "ergo_library_coach_write" on public.ergo_library;
drop policy if exists ergo_library_coach_write_v88 on public.ergo_library;
create policy ergo_library_coach_write_v88 on public.ergo_library
for all to authenticated
using(public.can_create_training_library_v88())
with check(public.can_create_training_library_v88());

-- ============================================================
-- 4) ALTAS: VALIDACIÓN CONTRA LA TABLA DE EQUIPOS
-- ============================================================
create or replace function public.can_manage_registration_v88(p_team text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.is_coach()
      or (p_team is not null and exists(
        select 1 from public.team_staff_roles s
        where s.user_id=auth.uid() and s.staff_role='coach' and s.team_code=p_team
      ))
$$;
grant execute on function public.can_manage_registration_v88(text) to authenticated;

-- Los entrenadores de equipo pueden leer las altas dirigidas a sus equipos.
drop policy if exists registration_requests_team_coach_read_v81 on public.registration_requests;
drop policy if exists registration_requests_team_coach_read_v87 on public.registration_requests;
drop policy if exists registration_requests_team_coach_read_v88 on public.registration_requests;
create policy registration_requests_team_coach_read_v88
on public.registration_requests
for select to authenticated
using (
  requested_team is not null
  and public.can_manage_registration_v88(requested_team)
);

-- Compatibilidad con V87.
create or replace function public.can_manage_registration_v87(p_team text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_manage_registration_v88(p_team)
$$;

create or replace function public.approve_registration(p_request_id bigint,p_team_code text)
returns void language plpgsql security definer set search_path=public as $$
declare v_req public.registration_requests%rowtype; v_global boolean;
begin
  if not exists(select 1 from public.rowing_teams where code=p_team_code and is_active) then
    raise exception 'Equipo no válido o inactivo';
  end if;
  v_global:=public.is_coach();
  select * into v_req from public.registration_requests where id=p_request_id for update;
  if not found then raise exception 'Solicitud no encontrada'; end if;
  if v_req.status<>'pending' then raise exception 'La solicitud ya no está pendiente'; end if;
  if not public.can_manage_registration_v88(p_team_code) then raise exception 'No tienes permiso para gestionar ese equipo'; end if;
  if v_req.requested_team is not null and not public.can_manage_registration_v88(v_req.requested_team) then
    raise exception 'No tienes permiso para gestionar esa solicitud';
  end if;
  if v_req.requested_team is null and not v_global then
    raise exception 'Las solicitudes generales debe gestionarlas el entrenador administrador';
  end if;
  update public.profiles set team_code=p_team_code where user_id=v_req.user_id;
  update public.registration_requests set status='approved',assigned_team=p_team_code,reviewed_by=auth.uid(),reviewed_at=now(),updated_at=now() where id=p_request_id;
end $$;
grant execute on function public.approve_registration(bigint,text) to authenticated;

create or replace function public.reject_registration(p_request_id bigint)
returns void language plpgsql security definer set search_path=public as $$
declare v_req public.registration_requests%rowtype; v_global boolean;
begin
  v_global:=public.is_coach();
  select * into v_req from public.registration_requests where id=p_request_id for update;
  if not found then raise exception 'Solicitud no encontrada'; end if;
  if v_req.status<>'pending' then raise exception 'La solicitud ya no está pendiente'; end if;
  if v_req.requested_team is null then
    if not v_global then raise exception 'Las solicitudes generales debe gestionarlas el entrenador administrador'; end if;
  elsif not public.can_manage_registration_v88(v_req.requested_team) then
    raise exception 'No tienes permiso para gestionar esa solicitud';
  end if;
  update public.registration_requests set status='rejected',assigned_team=null,reviewed_by=auth.uid(),reviewed_at=now(),updated_at=now() where id=p_request_id;
end $$;
grant execute on function public.reject_registration(bigint) to authenticated;

-- Reactivación segura de un alta rechazada.
create or replace function public.reactivate_registration_v86()
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Sesión no iniciada'; end if;
  update public.registration_requests
  set status='pending',assigned_team=null,reviewed_by=null,reviewed_at=null,updated_at=now()
  where user_id=auth.uid() and status='rejected';
end $$;
grant execute on function public.reactivate_registration_v86() to authenticated;

-- En V88 el entrenador administrador/global gestiona todos los equipos activos, incluidos los creados después.
create or replace function public.global_coach_can_team_v72(p_team text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.is_coach()
$$;
grant execute on function public.global_coach_can_team_v72(text) to authenticated;

create or replace function public.can_edit_team_v72(p_team text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.is_coach() or public.staff_role_for_team_v72(p_team)='coach'
$$;
grant execute on function public.can_edit_team_v72(text) to authenticated;

create or replace function public.can_record_team_v72(p_team text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.is_coach() or coalesce(public.staff_role_for_team_v72(p_team),'') in ('coach','assistant')
$$;
grant execute on function public.can_record_team_v72(text) to authenticated;

create or replace function public.can_manage_team(p_team text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.can_edit_team_v72(p_team)
$$;
grant execute on function public.can_manage_team(text) to authenticated;
