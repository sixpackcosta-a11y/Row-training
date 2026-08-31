-- Row Training V38 · Biblioteca ERGO editable
create table if not exists public.ergo_library (
  code text primary key,
  name text not null,
  zone text,
  url text,
  teams text not null default 'both',
  phases text not null default 'base,development,precomp,competition',
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.ergo_library enable row level security;
drop policy if exists "ergo_library_read" on public.ergo_library;
create policy "ergo_library_read" on public.ergo_library for select to authenticated using (true);
drop policy if exists "ergo_library_coach_write" on public.ergo_library;
create policy "ergo_library_coach_write" on public.ergo_library for all to authenticated using (public.is_coach()) with check (public.is_coach());
grant select on public.ergo_library to authenticated;
grant insert, update, delete on public.ergo_library to authenticated;

insert into public.ergo_library(code,name,zone,url,teams,phases) values
('UT2-2X10-20','UT2 · 2×10'' @20 · rec 3''','UT2','https://workout.ergdata.com/shared/vdc44zna','both','base,development'),
('UT2-3X10-20','UT2 · 3×10'' @20 · rec 3''','UT2','https://workout.ergdata.com/shared/dp1o0oix','both','base,development'),
('UT2-2X12-20','UT2 · 2×12'' @20 · rec 3''','UT2','https://workout.ergdata.com/shared/u2a1tacz','both','base,development'),
('UT2-3X12-20','UT2 · 3×12'' @20 · rec 3''','UT2','https://workout.ergdata.com/shared/u357fzbe','both','base,development'),
('UT1-4X700-24','UT1 · 4×700 m @24 · rec 2''','UT1','https://workout.ergdata.com/shared/xk0qkeou','both','base,development'),
('UT1-5X700-24','UT1 · 5×700 m @24 · rec 2''','UT1','https://workout.ergdata.com/shared/hjny07w2','both','development'),
('UT1-6X700-24','UT1 · 6×700 m @24 · rec 2''','UT1','https://workout.ergdata.com/shared/izhjtc4z','senior','development,precomp'),
('UT1-5X500-24','UT1 · 5×500 m @24 · rec 2''','UT1','https://workout.ergdata.com/shared/unaixamh','both','development'),
('UT1-2X1000-24','UT1 · 2×1000 m @24 · rec 3''','UT1','https://workout.ergdata.com/shared/zu6xsvr2','both','development'),
('UT1-3X1000-24','UT1 · 3×1000 m @24 · rec 3''','UT1','https://workout.ergdata.com/shared/oppqkx2o','both','development'),
('UT1-2X2000-24','UT1 · 2×2000 m @24 · rec 4''','UT1','https://workout.ergdata.com/shared/6ie64y6v','senior','development,precomp'),
('UT1-2X12-22','UT1 · 2×12'' @22 · rec 3''','UT1','https://workout.ergdata.com/shared/andz4pbf','both','base,development'),
('UT1AT-PROG28','UT1-AT · 28'' progresivo · 20→28 ppm','UT1-AT','https://workout.ergdata.com/shared/qjlppccd','both','development,precomp'),
('UT1AT-3X1500','UT1-AT · 3×(500@22 + 500@24 + 500@26) · rec 4''','UT1-AT','https://workout.ergdata.com/shared/mhfsanvv','both','development,precomp')
on conflict(code) do update set name=excluded.name,zone=excluded.zone,url=excluded.url,teams=excluded.teams,phases=excluded.phases,updated_at=now();
