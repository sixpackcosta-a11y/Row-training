-- Row Training V37 · matching automático ERGO ↔ Concept2
-- Ejecutar una vez en Supabase > SQL Editor. Es compatible con V36.

alter table public.ergo_intents
  add column if not exists expected_duration_seconds integer,
  add column if not exists expected_spm integer,
  add column if not exists status text not null default 'scheduled';

-- Evita duplicar la misma sesión al abrir Hoy/Semana varias veces.
create unique index if not exists ergo_intents_user_date_code_uidx
  on public.ergo_intents(user_id, scheduled_date, session_code);

-- La función de Vercel usa service_role para leer/escribir conexiones y resultados.
grant select, insert, update, delete on public.concept2_connections to service_role;
grant select, insert, update, delete on public.concept2_results to service_role;
grant select, insert, update, delete on public.ergo_intents to service_role;
grant usage, select on sequence public.concept2_results_id_seq to service_role;
grant usage, select on sequence public.ergo_intents_id_seq to service_role;
