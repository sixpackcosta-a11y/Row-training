-- Row Training V47
-- Resultados MAR por ejercicio/bloque para comparación longitudinal del equipo.
alter table public.sea_results add column if not exists exercise_name text;
create index if not exists sea_results_training_session_idx on public.sea_results(training_session_id);
