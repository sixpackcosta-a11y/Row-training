-- V144 · Oculta de forma reversible el histórico Concept2 anterior al inicio
-- de la temporada. No borra resultados ni modifica la planificación.
update public.concept2_results
set hidden=true,updated_at=now()
where workout_date<'2026-09-01'::timestamptz
  and hidden is distinct from true;
