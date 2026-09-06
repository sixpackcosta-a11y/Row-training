-- Row Training V137 · actualización acumulativa
-- 1) Conserva y repara la distribución semanal de V136 sin recrear sesiones.
-- 2) Añade almacenamiento privado para capturas de Rowing Coach en resultados MAR.

begin;

alter table public.sea_results
  add column if not exists photo_paths text[] not null default '{}'::text[];

comment on column public.sea_results.photo_paths is
'Rutas privadas de capturas de Rowing Coach asociadas al registro MAR.';

insert into storage.buckets (id,name,public,file_size_limit)
values ('sea-media','sea-media',false,15728640)
on conflict (id) do update
set public=false,
    file_size_limit=excluded.file_size_limit;

drop policy if exists sea_media_read_v137 on storage.objects;
create policy sea_media_read_v137 on storage.objects for select to authenticated
using (
  bucket_id='sea-media' and (
    public.is_coach()
    or exists (
      select 1 from public.team_staff_roles s
      where s.user_id=auth.uid()
        and s.team_code=split_part(name,'/',1)
        and s.staff_role in ('coach','assistant')
    )
  )
);

drop policy if exists sea_media_insert_v137 on storage.objects;
create policy sea_media_insert_v137 on storage.objects for insert to authenticated
with check (
  bucket_id='sea-media' and (
    public.is_coach()
    or exists (
      select 1 from public.team_staff_roles s
      where s.user_id=auth.uid()
        and s.team_code=split_part(name,'/',1)
        and s.staff_role in ('coach','assistant')
    )
  )
);

drop policy if exists sea_media_update_v137 on storage.objects;
create policy sea_media_update_v137 on storage.objects for update to authenticated
using (
  bucket_id='sea-media' and (
    public.is_coach()
    or exists (
      select 1 from public.team_staff_roles s
      where s.user_id=auth.uid()
        and s.team_code=split_part(name,'/',1)
        and s.staff_role in ('coach','assistant')
    )
  )
)
with check (
  bucket_id='sea-media' and (
    public.is_coach()
    or exists (
      select 1 from public.team_staff_roles s
      where s.user_id=auth.uid()
        and s.team_code=split_part(name,'/',1)
        and s.staff_role in ('coach','assistant')
    )
  )
);

drop policy if exists sea_media_delete_v137 on storage.objects;
create policy sea_media_delete_v137 on storage.objects for delete to authenticated
using (
  bucket_id='sea-media' and (
    public.is_coach()
    or exists (
      select 1 from public.team_staff_roles s
      where s.user_id=auth.uid()
        and s.team_code=split_part(name,'/',1)
        and s.staff_role in ('coach','assistant')
    )
  )
);

-- Parar sin modificar nada si una sesión manual ocupa un jueves de destino.
do $$
begin
  if exists (
    select 1
    from public.training_sessions source
    join public.training_sessions manual
      on manual.team_code=source.team_code
     and manual.session_date=source.session_date+
       case
         when source.team_code='veteranas' and extract(isodow from source.session_date)=1 then 3
         when extract(isodow from source.session_date)=3 then 1
         else 0
       end
     and manual.session_type=source.session_type
     and manual.created_by is not null
    where source.team_code in ('veteranas','senior_m')
      and source.session_date between date '2026-09-07' and date '2027-01-10'
      and source.created_by is null
      and (
        (source.team_code='veteranas' and source.session_type='GYM' and extract(isodow from source.session_date)=1)
        or (source.session_type in ('GYM','ERG') and extract(isodow from source.session_date)=3)
      )
  ) then
    raise exception 'V137: hay una sesión manual en un jueves de destino. No se ha modificado nada.';
  end if;
end $$;

-- Veteranas: GYM principal del lunes al jueves conjunto.
update public.training_sessions
set session_date=session_date+3, updated_at=now()
where team_code='veteranas' and session_type='GYM'
  and session_date between date '2026-09-07' and date '2027-01-10'
  and extract(isodow from session_date)=1 and created_by is null;

-- Ambos equipos: ERGO del miércoles al jueves conjunto.
update public.training_sessions
set session_date=session_date+1, updated_at=now()
where team_code in ('veteranas','senior_m') and session_type='ERG'
  and session_date between date '2026-09-07' and date '2027-01-10'
  and extract(isodow from session_date)=3 and created_by is null;

-- Senior: conserva el GYM propio del lunes y mueve solo su GYM complementario.
update public.training_sessions
set session_date=session_date+1, updated_at=now()
where team_code='senior_m' and session_type='GYM'
  and session_date between date '2026-09-07' and date '2027-01-10'
  and extract(isodow from session_date)=3 and created_by is null;

-- Validaciones: cualquier error deshace toda la actualización.
do $$
begin
  if exists (
    select 1 from public.training_sessions
    where team_code='veteranas'
      and session_date between date '2026-09-07' and date '2027-01-10'
      and created_by is null and session_type in ('GYM','ERG')
      and extract(isodow from session_date) in (1,3)
  ) then raise exception 'V137: quedan sesiones automáticas de Veteranas en lunes o miércoles.'; end if;

  if exists (
    select 1 from public.training_sessions
    where team_code='senior_m'
      and session_date between date '2026-09-07' and date '2027-01-10'
      and created_by is null and session_type in ('GYM','ERG')
      and extract(isodow from session_date)=3
  ) then raise exception 'V137: quedan sesiones automáticas de Senior en miércoles.'; end if;

  if exists (
    select 1 from public.training_sessions
    where team_code in ('veteranas','senior_m')
      and session_date between date '2026-09-07' and date '2027-01-10'
      and created_by is null and session_type='MAR'
      and extract(isodow from session_date) not in (2,7)
  ) then raise exception 'V137: existe una sesión MAR automática fuera de martes o domingo.'; end if;
end $$;

commit;

select
  exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='sea_results' and column_name='photo_paths'
  ) as fotos_mar_activas,
  exists(select 1 from storage.buckets where id='sea-media') as almacen_fotos_mar_activo;

select team_code,extract(isodow from session_date)::int as dia_semana,session_type,count(*) as sesiones
from public.training_sessions
where team_code in ('veteranas','senior_m')
  and session_date between date '2026-09-07' and date '2027-01-10'
  and created_by is null
group by team_code,extract(isodow from session_date),session_type
order by team_code,dia_semana,session_type;
