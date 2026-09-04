-- Row Training V124
-- Parciales y fotos en registros manuales de ergómetro.

begin;

alter table public.ergo_results
  add column if not exists splits jsonb not null default '[]'::jsonb,
  add column if not exists photo_paths text[] not null default '{}'::text[];

comment on column public.ergo_results.splits is
'Parciales introducidos manualmente: metros, tiempo, ritmo, ppm, FC y descanso.';

comment on column public.ergo_results.photo_paths is
'Rutas privadas de las fotografías de la pantalla del ergómetro.';

insert into storage.buckets (id,name,public,file_size_limit)
values ('ergo-media','ergo-media',false,15728640)
on conflict (id) do update
set public=false,
    file_size_limit=excluded.file_size_limit;

drop policy if exists ergo_media_read_v124 on storage.objects;
create policy ergo_media_read_v124 on storage.objects
for select to authenticated
using (
  bucket_id='ergo-media'
  and (
    split_part(name,'/',1)=auth.uid()::text
    or exists (
      select 1 from public.profiles p
      where p.user_id::text=split_part(name,'/',1)
        and public.can_record_athlete_v72(p.user_id)
    )
  )
);

drop policy if exists ergo_media_insert_v124 on storage.objects;
create policy ergo_media_insert_v124 on storage.objects
for insert to authenticated
with check (
  bucket_id='ergo-media'
  and (
    split_part(name,'/',1)=auth.uid()::text
    or exists (
      select 1 from public.profiles p
      where p.user_id::text=split_part(name,'/',1)
        and public.can_record_athlete_v72(p.user_id)
    )
  )
);

drop policy if exists ergo_media_update_v124 on storage.objects;
create policy ergo_media_update_v124 on storage.objects
for update to authenticated
using (
  bucket_id='ergo-media'
  and (
    split_part(name,'/',1)=auth.uid()::text
    or exists (
      select 1 from public.profiles p
      where p.user_id::text=split_part(name,'/',1)
        and public.can_record_athlete_v72(p.user_id)
    )
  )
)
with check (
  bucket_id='ergo-media'
  and (
    split_part(name,'/',1)=auth.uid()::text
    or exists (
      select 1 from public.profiles p
      where p.user_id::text=split_part(name,'/',1)
        and public.can_record_athlete_v72(p.user_id)
    )
  )
);

drop policy if exists ergo_media_delete_v124 on storage.objects;
create policy ergo_media_delete_v124 on storage.objects
for delete to authenticated
using (
  bucket_id='ergo-media'
  and (
    split_part(name,'/',1)=auth.uid()::text
    or exists (
      select 1 from public.profiles p
      where p.user_id::text=split_part(name,'/',1)
        and public.can_record_athlete_v72(p.user_id)
    )
  )
);

commit;

select
  exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='ergo_results' and column_name='splits'
  ) as parciales_activos,
  exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='ergo_results' and column_name='photo_paths'
  ) as fotos_activas,
  exists(select 1 from storage.buckets where id='ergo-media') as almacen_fotos_activo;
