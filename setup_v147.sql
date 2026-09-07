-- Row Training V147 · ocultación reversible de registros GYM/ERGO manuales.
-- Ejecutar UNA VEZ. No borra entrenamientos ni resultados.

alter table public.workout_logs
  add column if not exists hidden boolean not null default false;

grant select,update on table public.workout_logs to service_role;

comment on column public.workout_logs.hidden is
  'Ocultación reversible del historial. Los registros ocultos no cuentan en cumplimiento.';
