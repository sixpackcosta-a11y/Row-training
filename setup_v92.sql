-- Row Training V89 · equipos dinámicos + biblioteca compartida + multimedia GYM
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


-- ============================================================
-- 5) V89 · TODAS LAS PLANTILLAS BASE PERSISTENTES / ARCHIVABLES
-- ============================================================
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','CALENTAMIENTO · Calentamiento corto 10 min','CALENTAMIENTO · 10 min · 16–20 ppm progresivo + movilidad/activación',true,true,null,'Sistema','{"category":"warmup"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='CALENTAMIENTO · Calentamiento corto 10 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','CALENTAMIENTO · Calentamiento general 12 min','CALENTAMIENTO · 12 min · 16–20 ppm progresivo + movilidad/activación',true,true,null,'Sistema','{"category":"warmup"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='CALENTAMIENTO · Calentamiento general 12 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','CALENTAMIENTO · Calentamiento completo 15 min','CALENTAMIENTO · 15 min · 16–20 ppm progresivo + 3 aceleraciones cortas',true,true,null,'Sistema','{"category":"warmup"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='CALENTAMIENTO · Calentamiento completo 15 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Técnica continua 8 min','TÉCNICA · 8 min a 15–18 ppm · coordinación, entrada limpia y salida de brazos',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Técnica continua 8 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Técnica 3×4 min','TÉCNICA · 3×4 min a 15–18 ppm · rec 1 min · entrada, salida de brazos, core y secuencia',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Técnica 3×4 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Técnica 4×5 min','TÉCNICA · 4×5 min a 16–20 ppm · rec 1 min · un foco técnico por bloque',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Técnica 4×5 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Salidas 6×15 paladas','SALIDAS · 6×15 paladas · recuperación 45–60 s · salida propia del equipo',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Salidas 6×15 paladas');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Salidas 8×20 paladas','SALIDAS · 8×20 paladas · recuperación 60–75 s · calidad antes que fatiga',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Salidas 8×20 paladas');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Virada-Ciaboga 6 rep','VIRADA-CIABOGA · 6 repeticiones · recuperación 60 s · máxima calidad técnica',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Virada-Ciaboga 6 rep');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Virada-Ciaboga 8 rep','VIRADA-CIABOGA · 8 repeticiones · recuperación 60–75 s · entrada y salida de virada',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Virada-Ciaboga 8 rep');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Base 2×7 min','BASE · 2×7 min a 18–20 ppm · rec 2 min · presión uniforme y palada larga',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Base 2×7 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Base 3×10 min','BASE · 3×10 min a 18–20 ppm · rec 2 min · ritmo estable',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Base 3×10 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Base 2×15 min','BASE · 2×15 min a 18–20 ppm · rec 3 min · ritmo conversacional y técnica estable',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Base 2×15 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Base continua 40 min','BASE · 40 min continuos a 18–20 ppm · presión uniforme y palada larga',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Base continua 40 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Pirámide 20-22-24-26-28','PIRÁMIDE · 3 min @20 + 3 min @22 + 3 min @24 + 3 min @26 + 3 min @28 ppm · continua, sin recuperación entre escalones',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Pirámide 20-22-24-26-28');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Cambios 6×3 min','CAMBIOS · 6×3 min alternando 2 min @20–22 + 1 min @26–28 ppm · rec 90 s',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Cambios 6×3 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Ritmo 8×2 min','SERIES · 8×2 min @26–30 ppm · rec 90 s · técnica sólida y velocidad controlada',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Ritmo 8×2 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Series 4×4 min','SERIES · 4×4 min · ppm a decisión del entrenador · rec 2 min',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Series 4×4 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · Series 6×4 min','SERIES · 6×4 min · ppm a decisión del entrenador · rec 2 min',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · Series 6×4 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · 4×500 m','SERIES · 4×500 m · ppm a decisión del entrenador · rec 2 min',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · 4×500 m');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · 5×500 m','SERIES · 5×500 m · ppm a decisión del entrenador · rec 2 min',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · 5×500 m');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · 4×700 m','SERIES · 4×700 m · ppm a decisión del entrenador · rec 2–3 min',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · 4×700 m');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · 5×700 m','SERIES · 5×700 m · ppm a decisión del entrenador · rec 2–3 min',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · 5×700 m');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · 6×700 m','SERIES · 6×700 m · ppm a decisión del entrenador · rec 2–3 min',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · 6×700 m');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','TRABAJO · 3×1000 m','SERIES · 3×1000 m · ppm a decisión del entrenador · rec 3 min',true,true,null,'Sistema','{"category":"work"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='TRABAJO · 3×1000 m');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','RECUPERACIÓN · Recuperación 1 min','RECUPERACIÓN · 1 min · remo muy suave o parada según el bloque',true,true,null,'Sistema','{"category":"recovery"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='RECUPERACIÓN · Recuperación 1 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','RECUPERACIÓN · Recuperación 2 min','RECUPERACIÓN · 2 min · remo muy suave o parada según el bloque',true,true,null,'Sistema','{"category":"recovery"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='RECUPERACIÓN · Recuperación 2 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','RECUPERACIÓN · Recuperación 3 min','RECUPERACIÓN · 3 min · remo muy suave o parada según el bloque',true,true,null,'Sistema','{"category":"recovery"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='RECUPERACIÓN · Recuperación 3 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','VUELTA A LA CALMA · Vuelta a la calma 8–10 min','VUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave',true,true,null,'Sistema','{"category":"cooldown"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='VUELTA A LA CALMA · Vuelta a la calma 8–10 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','VUELTA A LA CALMA · Vuelta a la calma 12 min','VUELTA A LA CALMA · 12 min · 15–18 ppm muy suave',true,true,null,'Sistema','{"category":"cooldown"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='VUELTA A LA CALMA · Vuelta a la calma 12 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Recuperación + técnica','CALENTAMIENTO · 10 min · 16–18 ppm progresivo
TÉCNICA · 4×5 min a 16–18 ppm · rec 1 min · un foco técnico por bloque
BASE · 10 min a 18 ppm · palada larga y relajada
VUELTA A LA CALMA · 8 min · 15–18 ppm muy suave',true,true,null,'Sistema','{"objective":"Técnica","load":"Suave"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Recuperación + técnica');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Base + técnica','CALENTAMIENTO · 12 min · 16–20 ppm progresivo + movilidad/activación
TÉCNICA · 3×4 min a 15–18 ppm · rec 1 min · entrada, salida de brazos, core y secuencia
BASE · 2×7 min a 18–20 ppm · rec 2 min · presión uniforme y palada larga
RECUPERACIÓN · 2 min · entre bloques si hace falta
VUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave',true,true,null,'Sistema','{"objective":"Base / técnica","load":"Suave-media"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Base + técnica');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Base aeróbica 3×10','CALENTAMIENTO · 12 min · 16–20 ppm progresivo
BASE · 3×10 min a 18–20 ppm · rec 2 min · ritmo estable y técnica larga
VUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave',true,true,null,'Sistema','{"objective":"Base aeróbica","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Base aeróbica 3×10');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Base aeróbica 2×15','CALENTAMIENTO · 12 min · 16–20 ppm progresivo
BASE · 2×15 min a 18–20 ppm · rec 3 min · presión uniforme
TÉCNICA · 8 min a 16–18 ppm · coordinación
VUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave',true,true,null,'Sistema','{"objective":"Base aeróbica","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Base aeróbica 2×15');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Base continua larga','CALENTAMIENTO · 12 min · 16–20 ppm progresivo
BASE · 40 min continuos a 18–20 ppm · palada larga, ritmo conversacional
VUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave',true,true,null,'Sistema','{"objective":"Base aeróbica","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Base continua larga');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Técnica + salidas','CALENTAMIENTO · 12 min · 16–20 ppm progresivo
TÉCNICA · 3×4 min a 15–18 ppm · rec 1 min
SALIDAS · 6×15 paladas · recuperación 45–60 s
BASE · 2×7 min a 18–20 ppm · rec 2 min
VUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave',true,true,null,'Sistema','{"objective":"Técnica / salidas","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Técnica + salidas');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Viradas + salidas','CALENTAMIENTO · 12 min · 16–20 ppm progresivo
TÉCNICA · 8 min · coordinación y entrada limpia
VIRADA-CIABOGA · 6 repeticiones · recuperación 60 s · máxima calidad técnica
SALIDAS · 6×15 paladas · recuperación 45–60 s
RECUPERACIÓN · 2 min · entre bloques si hace falta
VUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave',true,true,null,'Sistema','{"objective":"Viradas / salidas","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Viradas + salidas');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Viradas bajo fatiga controlada','CALENTAMIENTO · 15 min · progresivo + 3 aceleraciones
SERIES · 4×4 min @24–26 ppm · rec 2 min
VIRADA-CIABOGA · 8 repeticiones · recuperación 60–75 s · calidad técnica
SALIDAS · 4×15 paladas · recuperación 60 s
VUELTA A LA CALMA · 10 min · muy suave',true,true,null,'Sistema','{"objective":"Viradas","load":"Media-alta"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Viradas bajo fatiga controlada');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Técnica + cambios de ritmo','CALENTAMIENTO · 12 min · 16–20 ppm progresivo
TÉCNICA · 3×4 min a 15–18 ppm · rec 1 min
PIRÁMIDE · 3 min @20 + 3 min @22 + 3 min @24 + 3 min @26 + 3 min @28 ppm · continua
SALIDAS · 6×15 paladas · recuperación 45–60 s
RECUPERACIÓN · 2 min · entre bloques si hace falta
VUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave',true,true,null,'Sistema','{"objective":"Cambios de ritmo","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Técnica + cambios de ritmo');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Cambios 6×3','CALENTAMIENTO · 12 min · progresivo
CAMBIOS · 6×3 min alternando 2 min @20–22 + 1 min @26–28 ppm · rec 90 s
BASE · 10 min @18–20 ppm · técnica estable
VUELTA A LA CALMA · 8–10 min · muy suave',true,true,null,'Sistema','{"objective":"Cambios de ritmo","load":"Media-alta"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Cambios 6×3');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Ritmo 8×2 min','CALENTAMIENTO · 15 min · progresivo + 3 aceleraciones
SERIES · 8×2 min @26–30 ppm · rec 90 s · técnica sólida
RECUPERACIÓN · 3 min · remo suave
SALIDAS · 4×15 paladas · recuperación 60 s
VUELTA A LA CALMA · 10 min · muy suave',true,true,null,'Sistema','{"objective":"Ritmo / velocidad","load":"Alta controlada"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Ritmo 8×2 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · 4×500 m controlados','CALENTAMIENTO · 15 min · progresivo
TÉCNICA · 8 min · coordinación
SERIES · 4×500 m · ppm a decisión del entrenador · rec 2 min
BASE · 8 min suave-técnico
VUELTA A LA CALMA · 10 min · muy suave',true,true,null,'Sistema','{"objective":"Series por metros","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · 4×500 m controlados');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · 5×500 m progresivos','CALENTAMIENTO · 15 min · progresivo + 3 aceleraciones
SERIES · 5×500 m · de controlado a vivo · rec 2 min
RECUPERACIÓN · 3 min · remo suave
SALIDAS · 4×15 paladas · recuperación 60 s
VUELTA A LA CALMA · 10 min · muy suave',true,true,null,'Sistema','{"objective":"Series por metros","load":"Media-alta"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · 5×500 m progresivos');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · 4×700 m ritmo sostenido','CALENTAMIENTO · 15 min · progresivo
SERIES · 4×700 m · ritmo sostenido · rec 2–3 min
TÉCNICA · 8 min suave · corregir detalles
VUELTA A LA CALMA · 10 min · muy suave',true,true,null,'Sistema','{"objective":"Series por metros","load":"Media-alta"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · 4×700 m ritmo sostenido');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · 5×700 m específico','CALENTAMIENTO · 15 min · progresivo + 3 aceleraciones
SERIES · 5×700 m · ritmo específico controlado · rec 3 min
RECUPERACIÓN · 3 min · remo suave
VUELTA A LA CALMA · 10 min · muy suave',true,true,null,'Sistema','{"objective":"Series por metros","load":"Alta controlada"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · 5×700 m específico');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · 3×1000 m resistencia específica','CALENTAMIENTO · 15 min · progresivo
SERIES · 3×1000 m · ritmo fuerte sostenible · rec 3 min
BASE · 8 min @18–20 ppm · soltar
VUELTA A LA CALMA · 10 min · muy suave',true,true,null,'Sistema','{"objective":"Series por metros","load":"Alta controlada"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · 3×1000 m resistencia específica');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · 6×4 min ritmo controlado','CALENTAMIENTO · 15 min · progresivo
SERIES · 6×4 min @24–28 ppm · rec 2 min
RECUPERACIÓN · 3 min · suave
VUELTA A LA CALMA · 10 min · muy suave',true,true,null,'Sistema','{"objective":"Ritmo / resistencia","load":"Media-alta"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · 6×4 min ritmo controlado');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'MAR','SESIÓN · Mixta completa 70–80 min','CALENTAMIENTO · 15 min · progresivo
TÉCNICA · 3×4 min a 16–18 ppm · rec 1 min
BASE · 2×15 min a 18–20 ppm · rec 3 min
SALIDAS · 6×15 paladas · recuperación 60 s
VIRADA-CIABOGA · 6 repeticiones · recuperación 60 s
VUELTA A LA CALMA · 10 min · muy suave',true,true,null,'Sistema','{"objective":"Mixta","load":"Media-alta"}'::jsonb
where not exists (select 1 from public.training_library where kind='MAR' and name='SESIÓN · Mixta completa 70–80 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Prensa de piernas','DOSIS · 3×10
DESCANSO · 75 s
INDICACIONES · Apoya espalda y pelvis. Baja con control y empuja con todo el pie sin bloquear las rodillas.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Prensa de piernas');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Remo sentado en polea','DOSIS · 3×10
DESCANSO · 60 s
INDICACIONES · Desde brazos extendidos, lleva el agarre al abdomen manteniendo el tronco estable.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Remo sentado en polea');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Hip thrust','DOSIS · 3×10
DESCANSO · 75 s
INDICACIONES · Eleva la cadera hasta alinear hombros, cadera y rodillas; pausa y baja controlando.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Hip thrust');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Pallof press','DOSIS · 2×10/lado
DESCANSO · 45 s
INDICACIONES · De lado al cable, extiende los brazos sin permitir que el tronco rote.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Pallof press');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Peso muerto rumano','DOSIS · 3×10
DESCANSO · 90 s
INDICACIONES · Lleva la cadera atrás con la carga cerca de las piernas y la espalda neutra; vuelve extendiendo la cadera.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Peso muerto rumano');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Press de pecho','DOSIS · 3×10
DESCANSO · 90 s
INDICACIONES · Empuja desde el pecho con muñecas neutras y hombros estables; vuelve con control.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Press de pecho');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Dead bug','DOSIS · 3×8/lado
DESCANSO · 45 s
INDICACIONES · Extiende brazo y pierna contrarios sin perder la posición lumbar.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Dead bug');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Jalón al pecho','DOSIS · 3×10
DESCANSO · 75–90 s
INDICACIONES · Lleva la barra a la parte alta del pecho bajando los codos sin balanceo.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Jalón al pecho');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Salto al cajón','DOSIS · 3×5
DESCANSO · 90–120 s
INDICACIONES · Salta a una altura cómoda, aterriza estable y baja andando.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Salto al cajón');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Remo en tabla / remo tumbado','DOSIS · 3×10
DESCANSO · 75–90 s
INDICACIONES · Con el pecho apoyado, lleva los codos atrás sin despegar el tronco.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Remo en tabla / remo tumbado');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Escaleras','DOSIS · 6×40 s
DESCANSO · 60–75 s
INDICACIONES · Sube con técnica y baja andando para recuperar.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Escaleras');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Burpees','DOSIS · 3×8
DESCANSO · 60–75 s
INDICACIONES · Realiza el gesto de forma controlada; el salto puede omitirse.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Burpees');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Carrera suave','DOSIS · 10–12 min
DESCANSO · —
INDICACIONES · Carrera cómoda a ritmo conversacional.',true,true,null,'Sistema','{"tags":[]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Carrera suave');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Sentadilla goblet a cajón','DOSIS · 3×8–10
DESCANSO · 90 s
INDICACIONES · Sentadilla controlada a cajón con carga delante del pecho. Rodillas alineadas y pie completo apoyado.',true,true,null,'Sistema','{"tags":["piernas","general"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Sentadilla goblet a cajón');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Step-up a cajón','DOSIS · 3×8/lado
DESCANSO · 75–90 s
INDICACIONES · Sube al cajón empujando con la pierna de apoyo, sin impulsarte con la pierna trasera.',true,true,null,'Sistema','{"tags":["piernas","unilateral"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Step-up a cajón');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Zancada atrás','DOSIS · 3×8/lado
DESCANSO · 75–90 s
INDICACIONES · Da un paso atrás, baja con control y vuelve empujando con el pie delantero.',true,true,null,'Sistema','{"tags":["piernas","unilateral"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Zancada atrás');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Curl femoral en máquina','DOSIS · 3×10
DESCANSO · 75 s
INDICACIONES · Flexiona rodillas sin despegar la cadera del apoyo. Regresa lento.',true,true,null,'Sistema','{"tags":["posterior","piernas"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Curl femoral en máquina');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Elevación de gemelos','DOSIS · 3×12–15
DESCANSO · 60 s
INDICACIONES · Sube y baja de puntillas con recorrido completo y control.',true,true,null,'Sistema','{"tags":["piernas"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Elevación de gemelos');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Face pull','DOSIS · 3×12
DESCANSO · 60 s
INDICACIONES · Tira de la cuerda hacia la cara con codos altos y hombros lejos de las orejas.',true,true,null,'Sistema','{"tags":["tiron","hombro"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Face pull');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Press de hombro en máquina','DOSIS · 3×8–10
DESCANSO · 75–90 s
INDICACIONES · Empuja por encima de la cabeza sin arquear la zona lumbar y sin dolor.',true,true,null,'Sistema','{"tags":["empuje","hombro"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Press de hombro en máquina');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Remo con mancuerna a una mano','DOSIS · 3×10/lado
DESCANSO · 60–75 s
INDICACIONES · Apoya bien el tronco y lleva el codo hacia la cadera sin girarte.',true,true,null,'Sistema','{"tags":["tiron","espalda"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Remo con mancuerna a una mano');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Farmer carry','DOSIS · 4×30–40 m
DESCANSO · 60 s
INDICACIONES · Camina alto con cargas a los lados, abdomen firme y hombros estables.',true,true,null,'Sistema','{"tags":["agarre","core","general"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Farmer carry');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Plancha frontal','DOSIS · 3×30–45 s
DESCANSO · 45–60 s
INDICACIONES · Mantén una línea hombros-cadera-tobillos, abdomen y glúteos activos.',true,true,null,'Sistema','{"tags":["core"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Plancha frontal');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Plancha lateral','DOSIS · 3×25–40 s/lado
DESCANSO · 45 s
INDICACIONES · Mantén cadera elevada y cuerpo alineado sin rotar el tronco.',true,true,null,'Sistema','{"tags":["core"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Plancha lateral');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Bird dog','DOSIS · 3×8/lado
DESCANSO · 45 s
INDICACIONES · Extiende brazo y pierna contrarios sin mover pelvis ni zona lumbar.',true,true,null,'Sistema','{"tags":["core","estabilidad"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Bird dog');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Crunch en polea','DOSIS · 3×10–12
DESCANSO · 60 s
INDICACIONES · Flexiona el tronco acercando costillas a pelvis sin tirar con los brazos.',true,true,null,'Sistema','{"tags":["core"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Crunch en polea');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Elevación de rodillas','DOSIS · 3×10–12
DESCANSO · 60 s
INDICACIONES · Eleva rodillas con pelvis controlada y evita balancearte.',true,true,null,'Sistema','{"tags":["core"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Elevación de rodillas');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Puente de glúteo','DOSIS · 3×12
DESCANSO · 60–75 s
INDICACIONES · Eleva la cadera contrayendo glúteos sin hiperextender la espalda.',true,true,null,'Sistema','{"tags":["posterior","piernas"]}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Puente de glúteo');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Fuerza general corta 30–35 min','OBJETIVO · Fuerza general
CARGA · Suave-media · RIR 3
CALENTAMIENTO · 7 min · movilidad + activación
Prensa de piernas · 2×10 · rec 75 s
Remo sentado en polea · 2×10 · rec 60 s
Press de pecho · 2×10 · rec 75 s
Pallof press · 2×10/lado · rec 45 s
Plancha frontal · 2×30–40 s · rec 45 s',true,true,null,'Sistema','{"objective":"Fuerza general","load":"Suave-media"}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='SESIÓN · Fuerza general corta 30–35 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Fuerza general 45 min','OBJETIVO · Fuerza general
CARGA · Media · RIR 2–3
CALENTAMIENTO · 8 min · movilidad + activación
Prensa de piernas · 3×10 · rec 90 s
Peso muerto rumano · 3×10 · rec 90 s
Remo sentado en polea · 3×10 · rec 75 s
Press de pecho · 3×10 · rec 90 s
Pallof press · 3×10/lado · rec 45–60 s',true,true,null,'Sistema','{"objective":"Fuerza general","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='SESIÓN · Fuerza general 45 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Cadena posterior + tirón','OBJETIVO · Cadena posterior + tirón
CARGA · Media · RIR 2–3
CALENTAMIENTO · 8 min
Peso muerto rumano · 3×8–10 · rec 90 s
Hip thrust · 3×10 · rec 90 s
Jalón al pecho · 3×10 · rec 75–90 s
Remo sentado en polea · 3×10 · rec 75 s
Farmer carry · 3×30–40 m · rec 60 s
Plancha lateral · 2×30 s/lado · rec 45 s',true,true,null,'Sistema','{"objective":"Cadena posterior / espalda","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='SESIÓN · Cadena posterior + tirón');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Tren superior + core','OBJETIVO · Tren superior + core
CARGA · Media · RIR 2–3
CALENTAMIENTO · 7 min
Remo sentado en polea · 3×10 · rec 75 s
Jalón al pecho · 3×10 · rec 75 s
Press de pecho · 3×10 · rec 90 s
Face pull · 3×12 · rec 60 s
Pallof press · 3×10/lado · rec 45 s
Dead bug · 3×8/lado · rec 45 s',true,true,null,'Sistema','{"objective":"Espalda / empuje / core","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='SESIÓN · Tren superior + core');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Core completo 25–30 min','OBJETIVO · Core y estabilidad
CARGA · Media · técnica perfecta
CALENTAMIENTO · 5 min
Pallof press · 3×10/lado · rec 45 s
Dead bug · 3×8/lado · rec 45 s
Plancha frontal · 3×30–45 s · rec 45 s
Plancha lateral · 3×25–40 s/lado · rec 45 s
Bird dog · 3×8/lado · rec 45 s
Farmer carry · 3×30 m · rec 60 s',true,true,null,'Sistema','{"objective":"Core / estabilidad","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='SESIÓN · Core completo 25–30 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Pierna unilateral + core','OBJETIVO · Pierna unilateral + estabilidad
CARGA · Media · RIR 2–3
CALENTAMIENTO · 8 min
Sentadilla goblet a cajón · 3×8–10 · rec 90 s
Step-up a cajón · 3×8/lado · rec 75 s
Zancada atrás · 3×8/lado · rec 75 s
Curl femoral en máquina · 3×10 · rec 75 s
Plancha lateral · 3×30 s/lado · rec 45 s
Pallof press · 2×10/lado · rec 45 s',true,true,null,'Sistema','{"objective":"Piernas / estabilidad","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='SESIÓN · Pierna unilateral + core');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Senior · fuerza controlada 50–60 min','OBJETIVO · Fuerza útil para remo
CARGA · Alta controlada · RIR 1–2 en principales
CALENTAMIENTO · 10 min
Prensa de piernas · 4×8 · rec 2 min
Peso muerto rumano · 4×8 · rec 2 min
Remo sentado en polea · 4×8–10 · rec 90 s
Jalón al pecho · 3×8–10 · rec 90 s
Press de pecho · 3×8–10 · rec 90 s
Farmer carry · 4×30–40 m · rec 60 s
Pallof press · 3×10/lado · rec 45 s',true,true,null,'Sistema','{"objective":"Fuerza / rendimiento","load":"Alta controlada"}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='SESIÓN · Senior · fuerza controlada 50–60 min');

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Veteranas · fuerza segura 40–45 min','OBJETIVO · Fuerza general segura
CARGA · Media · RIR 2–3
CALENTAMIENTO · 8 min
Prensa de piernas · 3×10 · rec 90 s
Hip thrust · 3×10 · rec 90 s
Remo sentado en polea · 3×10 · rec 75 s
Press de pecho · 2×10 · rec 75 s
Pallof press · 2×10/lado · rec 45 s
Dead bug · 2×8/lado · rec 45 s',true,true,null,'Sistema','{"objective":"Fuerza general segura","load":"Media"}'::jsonb
where not exists (select 1 from public.training_library where kind='GYM' and name='SESIÓN · Veteranas · fuerza segura 40–45 min');

-- ============================================================
-- 6) V89 · ARCHIVADO SOLO ADMIN + EDICIÓN SEGURA
-- ============================================================
create or replace function public.can_edit_training_library_v89(p_created_by uuid,p_is_system boolean)
returns boolean language sql stable security definer set search_path=public as $$
  select public.is_coach() or (not coalesce(p_is_system,false) and p_created_by=auth.uid())
$$;
grant execute on function public.can_edit_training_library_v89(uuid,boolean) to authenticated;

drop policy if exists training_library_coach_update on public.training_library;
drop policy if exists training_library_coach_update_v89 on public.training_library;
create policy training_library_coach_update_v89 on public.training_library
for update to authenticated
using (public.can_edit_training_library_v89(created_by,is_system))
with check (public.can_edit_training_library_v89(created_by,is_system));

-- Un entrenador puede crear contenido propio, pero no hacerse pasar por plantilla del sistema.
drop policy if exists training_library_coach_insert on public.training_library;
drop policy if exists training_library_coach_insert_v89 on public.training_library;
create policy training_library_coach_insert_v89 on public.training_library
for insert to authenticated
with check (public.can_create_training_library_v88() and created_by=auth.uid() and coalesce(is_system,false)=false);

create or replace function public.guard_training_library_archive_v89()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if (new.archived_at is distinct from old.archived_at
      or new.archived_by is distinct from old.archived_by
      or new.is_active is distinct from old.is_active)
     and not public.is_coach() then
    raise exception 'Solo el administrador puede archivar o desarchivar elementos de la biblioteca';
  end if;
  return new;
end $$;

drop trigger if exists trg_training_library_archive_v89 on public.training_library;
create trigger trg_training_library_archive_v89
before update on public.training_library
for each row execute function public.guard_training_library_archive_v89();



-- ============================================================
-- V90 · PERTENENCIAS MULTIEQUIPO DE REMEROS
-- ============================================================
create table if not exists public.rower_team_memberships (
  user_id uuid not null references auth.users(id) on delete cascade,
  team_code text not null,
  is_rower boolean not null default true,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(user_id,team_code)
);
alter table public.rower_team_memberships enable row level security;
grant select,insert,update,delete on public.rower_team_memberships to authenticated;

-- Migra la pertenencia antigua de profiles.team_code sin eliminarla: queda como equipo principal/fallback.
insert into public.rower_team_memberships(user_id,team_code,is_rower,created_by)
select user_id,team_code,true,null from public.profiles where team_code is not null
on conflict(user_id,team_code) do update set is_rower=true,updated_at=now();

drop policy if exists rower_team_memberships_read_v90 on public.rower_team_memberships;
create policy rower_team_memberships_read_v90 on public.rower_team_memberships for select to authenticated
using (user_id=auth.uid() or public.is_coach() or exists(select 1 from public.team_staff_roles s where s.user_id=auth.uid() and s.team_code=rower_team_memberships.team_code));
drop policy if exists rower_team_memberships_admin_write_v90 on public.rower_team_memberships;
create policy rower_team_memberships_admin_write_v90 on public.rower_team_memberships for all to authenticated
using (public.is_coach()) with check (public.is_coach());

-- ============================================================
-- V90 · REGATAS CONOCIDAS 2026
-- ============================================================
insert into public.competitions(name,competition_date,team_codes,priority,notes,created_by)
select 'XIII Liga Andaluza de banco fijo en llaut · 1ª regata · larga distancia','2026-10-24',array['veteranas','veteranos_m','senior_m','senior_f'],'A','El Palo (Málaga). Distancia: Veteranos/as 3000 m · Senior 4000 m.',null
where not exists(select 1 from public.competitions where competition_date='2026-10-24' and name ilike '%1ª regata%');
insert into public.competitions(name,competition_date,team_codes,priority,notes,created_by)
select 'Campeonato de Andalucía de larga distancia en banco fijo llaut','2026-12-12',array['veteranas','veteranos_m','senior_m','senior_f'],'A','Benalmádena (Málaga). Distancia: Veteranos/as 3000 m · Senior 4000 m.',null
where not exists(select 1 from public.competitions where competition_date='2026-12-12' and name ilike '%larga distancia%');

-- ============================================================
-- V90 · PLANIFICACIÓN COMPLETA 2026–27
-- Mantiene cualquier sesión que ya exista en ese equipo/día.
-- Patrón semanal: Mar MIX · Jue MAR · Vie GYM · Sáb ERGO · Dom MAR.
-- MAR sigue oculto para remeros según las políticas actuales.
-- ============================================================
with teams(team_code) as (values ('veteranas'),('senior_m')),
dates as (
 select d::date session_date, extract(isodow from d)::int dow
 from generate_series('2026-09-01'::date,'2027-05-30'::date,'1 day') d
),base as (
 select t.team_code,d.session_date,d.dow,
   case d.dow when 2 then 'MIX' when 4 then 'MAR' when 5 then 'GYM' when 6 then 'ERG' when 7 then 'MAR' end session_type
 from teams t cross join dates d where d.dow in (2,4,5,6,7)
),plan as (
 select *,
 case
  when session_date in ('2026-10-24','2026-12-12') then 'RACE'
  when session_date between '2026-10-19' and '2026-10-25' or session_date between '2026-12-07' and '2026-12-13' then 'RACEWEEK'
  when session_date in ('2026-09-27','2026-10-11','2026-11-15','2026-11-29') then 'SIM_LONG'
  when session_date in ('2027-01-31','2027-02-28','2027-03-28','2027-04-25','2027-05-16') then 'SIM_GENERIC'
  when session_date < '2026-10-05' then 'BASE'
  when session_date < '2026-10-19' then 'SPEC1'
  when session_date < '2026-11-16' then 'BASE2'
  when session_date < '2026-12-07' then 'SPEC2'
  when session_date < '2027-01-11' then 'RECOVERY'
  when session_date < '2027-03-01' then 'DEVELOPMENT'
  when session_date < '2027-04-12' then 'SPECIFIC'
  else 'PRECOMP' end phase
 from base
),rows as (
 select team_code,session_date,
 case when phase='RACE' then 'DESC' else session_type end as session_type,
 case
  when phase='RACE' then '🏁 REGATA · ver competición del día'
  when phase='SIM_LONG' and session_type='MAR' then case when team_code='senior_m' then 'MAR · Simulación larga distancia · 4000 m' else 'MAR · Simulación larga distancia · 3000 m' end
  when phase='SIM_GENERIC' and session_type='MAR' then 'MAR · Simulación de regata · distancia configurable'
  when phase='RACEWEEK' and dow=2 then 'MIX · Activación ligera semana de regata'
  when phase='RACEWEEK' and dow=4 then 'MAR · Activación + salidas · corta'
  when phase='RACEWEEK' and dow=5 then 'GYM · Activación 25–30 min'
  when phase='RACEWEEK' and dow=6 then 'DESC · Pre-regata'
  when dow=2 then case phase when 'BASE' then 'MIX · Fuerza general + ERGO UT2' when 'RECOVERY' then 'MIX · Recuperación + técnica' else 'MIX · Fuerza + ERGO progresivo' end
  when dow=4 then case phase when 'BASE' then 'MAR · Base + técnica' when 'BASE2' then 'MAR · Base aeróbica + técnica' when 'DEVELOPMENT' then 'MAR · Técnica + cambios de ritmo' when 'SPECIFIC' then 'MAR · Ritmo / viradas / salidas' when 'PRECOMP' then 'MAR · Ritmo competición + salidas' else 'MAR · Técnica + ritmo controlado' end
  when dow=5 then case phase when 'BASE' then 'GYM · Fuerza general 45 min' when 'RECOVERY' then 'GYM · Recuperación / movilidad' when 'DEVELOPMENT' then 'GYM · Fuerza completa 50–60 min' when 'SPECIFIC' then 'GYM · Fuerza específica remo' when 'PRECOMP' then 'GYM · Potencia controlada' else 'GYM · Fuerza equilibrada' end
  when dow=6 then case phase when 'BASE' then 'ERGO · UT2 progresivo' when 'RECOVERY' then 'ERGO · UT2 suave' when 'DEVELOPMENT' then 'ERGO · UT1 / AT progresivo' when 'SPECIFIC' then 'ERGO · Umbral / ritmo' when 'PRECOMP' then 'ERGO · Ritmo competición corto' else 'ERGO · Desarrollo aeróbico' end
  when dow=7 then case phase when 'BASE' then 'MAR · Base aeróbica' when 'BASE2' then 'MAR · Base larga + viradas' when 'DEVELOPMENT' then 'MAR · Series + técnica' when 'SPECIFIC' then 'MAR · Series específicas + viradas' when 'PRECOMP' then 'MAR · Simulación parcial / ritmo' else 'MAR · Base + técnica' end end title,
 case
  when phase='RACE' then 'Competición prioritaria. No añadir carga de entrenamiento.'
  when phase='SIM_LONG' and session_type='MAR' then case when team_code='senior_m' then 'CALENTAMIENTO · 15 min\nSALIDAS · 3×15 paladas\nSIMULACIÓN · 4000 m continuos · salida, ritmo de regata, viradas si proceden y cierre final\nOBJETIVO · ejecución y pacing; no hace falta buscar máximo absoluto en la primera simulación\nVUELTA A LA CALMA · 10 min' else 'CALENTAMIENTO · 15 min\nSALIDAS · 3×15 paladas\nSIMULACIÓN · 3000 m continuos · salida, ritmo de regata, viradas si proceden y cierre final\nOBJETIVO · ejecución y pacing; no hace falta buscar máximo absoluto en la primera simulación\nVUELTA A LA CALMA · 10 min' end
  when phase='SIM_GENERIC' and session_type='MAR' then 'CALENTAMIENTO · 15 min\nSIMULACIÓN DE REGATA · distancia configurable por entrenador según próxima prueba\nTRABAJO · salida + ritmo sostenido + virada(s) + final\nVUELTA A LA CALMA · 10 min'
  when phase='RACEWEEK' and dow=2 then '30–45 min total. GYM muy ligero + 15–20 min ERGO UT2. RIR 4. Salir fresco.'
  when phase='RACEWEEK' and dow=4 then 'CALENTAMIENTO · 12 min\nTÉCNICA · 8 min\nSALIDAS · 4×12–15 paladas · recuperación completa\nTRABAJO · 2×3 min a ritmo vivo, sin fatigar\nVUELTA A LA CALMA · 8 min'
  when phase='RACEWEEK' and dow=5 then 'Activación 25–30 min · 2 series por ejercicio · RIR 4 · sin agujetas ni fatiga residual.'
  when phase='RACEWEEK' and dow=6 then 'Descanso, movilidad breve, hidratación y preparación de material.'
  when dow=2 then 'GYM + ERGO combinados. Ajustar carga según fase. Duración objetivo 60–75 min. No llegar al fallo.'
  when dow=4 then 'CALENTAMIENTO · 12–15 min\nTÉCNICA · 10 min\nTRABAJO PRINCIPAL · 25–35 min según fase\nRECUPERACIÓN · según bloque\nVUELTA A LA CALMA · 8–10 min'
  when dow=5 then 'GYM según biblioteca y fase. Mantener técnica perfecta y margen de repeticiones. Duración 40–60 min.'
  when dow=6 then 'ERGO según zona de la fase. Calentamiento y vuelta a la calma incluidos. Progresión de fácil a exigente.'
  when dow=7 then 'CALENTAMIENTO · 12–15 min\nTRABAJO MAR · 35–50 min según fase\nIncluir técnica, salidas o viradas según objetivo semanal\nVUELTA A LA CALMA · 8–10 min' end content
 from plan
)
insert into public.training_sessions(team_code,session_date,session_type,title,content,created_by)
select r.team_code,r.session_date,r.session_type,r.title,r.content,null from rows r
where not exists(select 1 from public.training_sessions s where s.team_code=r.team_code and s.session_date=r.session_date);

-- ============================================================
-- V90 · SESIONES GYM ADICIONALES (archivables como el resto)
-- ============================================================
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Pierna unilateral + estabilidad · 40 min','OBJETIVO · Pierna unilateral + estabilidad\nCARGA · Media · RIR 2–3\nCALENTAMIENTO · 8 min\nSentadilla goblet a cajón · 3×8–10 · rec 90 s\nStep-up a cajón · 3×8/lado · rec 75 s\nZancada atrás · 3×8/lado · rec 75 s\nCurl femoral en máquina · 3×10 · rec 75 s\nPlancha lateral · 3×30 s/lado · rec 45 s\nPallof press · 2×10/lado · rec 45 s',true,true,null,'Sistema','{"objective":"Piernas / estabilidad","load":"Media","estimated_minutes":40}'::jsonb where not exists(select 1 from public.training_library where kind='GYM' and name='SESIÓN · Pierna unilateral + estabilidad · 40 min');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Cadena posterior fuerte · 50 min','OBJETIVO · Cadena posterior\nCARGA · Media-alta · RIR 1–2\nCALENTAMIENTO · 10 min\nPeso muerto rumano · 4×8 · rec 2 min\nHip thrust · 4×8–10 · rec 2 min\nCurl femoral · 3×10 · rec 75 s\nRemo sentado en polea · 3×10 · rec 75 s\nFarmer carry · 4×30 m · rec 60 s\nDead bug · 3×8/lado · rec 45 s',true,true,null,'Sistema','{"objective":"Cadena posterior","load":"Media-alta","estimated_minutes":50}'::jsonb where not exists(select 1 from public.training_library where kind='GYM' and name='SESIÓN · Cadena posterior fuerte · 50 min');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Tirón + core · 45 min','OBJETIVO · Espalda y core\nCARGA · Media\nCALENTAMIENTO · 8 min\nRemo sentado en polea · 4×10 · rec 75 s\nJalón al pecho · 4×8–10 · rec 90 s\nRemo unilateral · 3×10/lado · rec 75 s\nFace pull · 3×12 · rec 60 s\nPallof press · 3×10/lado · rec 45 s\nPlancha frontal · 3×40 s · rec 45 s',true,true,null,'Sistema','{"objective":"Espalda / core","load":"Media","estimated_minutes":45}'::jsonb where not exists(select 1 from public.training_library where kind='GYM' and name='SESIÓN · Tirón + core · 45 min');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Potencia controlada · 35 min','OBJETIVO · Potencia útil para remo\nCARGA · Media-alta · máxima calidad\nCALENTAMIENTO · 10 min\nSalto al cajón · 5×4 · rec 90 s\nSentadilla goblet rápida · 4×6 · rec 90 s\nRemo explosivo en polea · 4×6 · rec 75 s\nFarmer carry · 4×25 m · rec 60 s\nPlancha frontal · 3×30 s · rec 45 s',true,true,null,'Sistema','{"objective":"Potencia","load":"Media-alta","estimated_minutes":35}'::jsonb where not exists(select 1 from public.training_library where kind='GYM' and name='SESIÓN · Potencia controlada · 35 min');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Fuerza completa · 60 min','OBJETIVO · Fuerza útil para remo\nCARGA · Alta controlada · RIR 1–2\nCALENTAMIENTO · 10 min\nPrensa de piernas · 4×8 · rec 2 min\nPeso muerto rumano · 4×8 · rec 2 min\nRemo sentado en polea · 4×8–10 · rec 90 s\nJalón al pecho · 3×8–10 · rec 90 s\nPress de pecho · 3×8–10 · rec 90 s\nFarmer carry · 4×30–40 m · rec 60 s\nPallof press · 3×10/lado · rec 45 s',true,true,null,'Sistema','{"objective":"Fuerza / rendimiento","load":"Alta controlada","estimated_minutes":60}'::jsonb where not exists(select 1 from public.training_library where kind='GYM' and name='SESIÓN · Fuerza completa · 60 min');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Activación semana de regata · 25–30 min','OBJETIVO · Activar sin generar fatiga\nCARGA · Suave · RIR 4\nCALENTAMIENTO · 8 min\nPrensa de piernas · 2×8 · rec 90 s\nRemo sentado · 2×8 · rec 75 s\nPress de pecho · 2×8 · rec 75 s\nPallof press · 2×8/lado · rec 45 s\nTerminar con sensación de frescura',true,true,null,'Sistema','{"objective":"Activación","load":"Suave","estimated_minutes":28}'::jsonb where not exists(select 1 from public.training_library where kind='GYM' and name='SESIÓN · Activación semana de regata · 25–30 min');

-- ============================================================
-- V92 · AGARRE + CLASIFICACIÓN MULTIETIQUETA
-- ============================================================

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Dead hang / suspensión en barra','DOSIS · 3×20–40 s
DESCANSO · 60–90 s
INDICACIONES · Suspéndete de la barra con hombros activos y tronco estable. No aguantes dolor en hombro o codo.',true,true,null,'Sistema','{"tags":["agarre","tiron"]}'::jsonb
where not exists(select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Dead hang / suspensión en barra');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Plate pinch hold / pinza con discos','DOSIS · 3×20–30 s/lado
DESCANSO · 60 s
INDICACIONES · Sujeta uno o dos discos con pinza de dedos, muñeca neutra y hombro relajado.',true,true,null,'Sistema','{"tags":["agarre"]}'::jsonb
where not exists(select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Plate pinch hold / pinza con discos');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Agarre con toalla en barra','DOSIS · 3×15–30 s
DESCANSO · 75–90 s
INDICACIONES · Sujeta una toalla pasada por la barra y mantén suspensión controlada; prioriza seguridad del hombro.',true,true,null,'Sistema','{"tags":["agarre","tiron"]}'::jsonb
where not exists(select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Agarre con toalla en barra');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Curl de muñeca','DOSIS · 3×12–15
DESCANSO · 45–60 s
INDICACIONES · Antebrazos apoyados, flexiona las muñecas con recorrido controlado sin mover los codos.',true,true,null,'Sistema','{"tags":["agarre"]}'::jsonb
where not exists(select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Curl de muñeca');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Curl inverso de muñeca','DOSIS · 3×12–15
DESCANSO · 45–60 s
INDICACIONES · Antebrazos apoyados y palmas hacia abajo; extiende las muñecas lentamente sin compensar con los brazos.',true,true,null,'Sistema','{"tags":["agarre"]}'::jsonb
where not exists(select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Curl inverso de muñeca');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Extensión de dedos con goma','DOSIS · 3×15–20
DESCANSO · 30–45 s
INDICACIONES · Abre los dedos contra una goma alrededor de ellos. Controla la vuelta y evita movimientos bruscos.',true,true,null,'Sistema','{"tags":["agarre"]}'::jsonb
where not exists(select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Extensión de dedos con goma');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','EJERCICIO · Sujeción isométrica pesada','DOSIS · 3×20–30 s
DESCANSO · 75–90 s
INDICACIONES · Mantén una barra o mancuernas pesadas con postura alta, muñeca neutra y abdomen firme.',true,true,null,'Sistema','{"tags":["agarre","core"]}'::jsonb
where not exists(select 1 from public.training_library where kind='GYM' and name='EJERCICIO · Sujeción isométrica pesada');

-- Asegura que Farmer carry conserve sus etiquetas aunque ya existiera de versiones previas.
update public.training_library
set metadata = coalesce(metadata,'{}'::jsonb) || '{"tags":["agarre","core","general"]}'::jsonb
where kind='GYM' and name='EJERCICIO · Farmer carry' and archived_at is null;

insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Agarre + core · 40 min','OBJETIVO · Agarre + estabilidad
CARGA · Media · calidad técnica
CALENTAMIENTO · 7 min
Farmer carry · 4×30 m · rec 60 s
Dead hang / suspensión en barra · 3×25 s · rec 75 s
Plate pinch hold / pinza con discos · 3×25 s/lado · rec 60 s
Pallof press · 3×10/lado · rec 45 s
Plancha frontal · 3×35 s · rec 45 s
Extensión de dedos con goma · 2×20 · rec 30 s',true,true,null,'Sistema','{"objective":"Agarre / Core","load":"Media","estimated_minutes":40}'::jsonb
where not exists(select 1 from public.training_library where kind='GYM' and name='SESIÓN · Agarre + core · 40 min');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Agarre + tirón · 45 min','OBJETIVO · Agarre + tirón
CARGA · Media · RIR 2–3
CALENTAMIENTO · 8 min
Remo sentado en polea · 3×10 · rec 75 s
Jalón al pecho · 3×10 · rec 75 s
Agarre con toalla en barra · 3×20 s · rec 90 s
Farmer carry · 4×30 m · rec 60 s
Curl inverso de muñeca · 3×15 · rec 45 s
Extensión de dedos con goma · 2×20 · rec 30 s',true,true,null,'Sistema','{"objective":"Agarre / Espalda","load":"Media","estimated_minutes":45}'::jsonb
where not exists(select 1 from public.training_library where kind='GYM' and name='SESIÓN · Agarre + tirón · 45 min');
insert into public.training_library(kind,name,content,is_active,is_system,created_by,created_by_name,metadata)
select 'GYM','SESIÓN · Bloque corto de agarre · 15–20 min','OBJETIVO · Refuerzo específico de agarre
CARGA · Suave-media
Dead hang / suspensión en barra · 3×20–30 s · rec 60 s
Plate pinch hold / pinza con discos · 3×20 s/lado · rec 45 s
Curl de muñeca · 2×15 · rec 45 s
Curl inverso de muñeca · 2×15 · rec 45 s
Extensión de dedos con goma · 2×20 · rec 30 s',true,true,null,'Sistema','{"objective":"Agarre","load":"Suave-media","estimated_minutes":20}'::jsonb
where not exists(select 1 from public.training_library where kind='GYM' and name='SESIÓN · Bloque corto de agarre · 15–20 min');
