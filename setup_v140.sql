-- Row Training V140 · vinculación explícita de resultados con la planificación
-- Ejecutar UNA VEZ después de setup_v139.sql.

alter table public.concept2_results
  add column if not exists training_session_id bigint
  references public.training_sessions(id) on delete set null;

alter table public.workout_logs
  add column if not exists training_session_id bigint
  references public.training_sessions(id) on delete set null;

alter table public.workout_logs
  add column if not exists performed_at timestamptz;

update public.workout_logs
set performed_at=created_at
where performed_at is null;

alter table public.workout_logs
  alter column performed_at set default now();

alter table public.ergo_intents
  add column if not exists training_session_id bigint
  references public.training_sessions(id) on delete set null;

create index if not exists concept2_results_training_session_v140_idx
  on public.concept2_results(user_id,training_session_id);

create index if not exists workout_logs_training_session_v140_idx
  on public.workout_logs(user_id,training_session_id);

comment on column public.concept2_results.training_session_id is
  'Sesión planificada a la que el remero ha asociado expresamente el resultado Concept2.';
comment on column public.workout_logs.training_session_id is
  'Sesión planificada realizada, aunque la fecha real del entrenamiento sea diferente.';
comment on column public.workout_logs.performed_at is
  'Fecha y hora reales del registro; session_date conserva la fecha de la planificación asociada.';
