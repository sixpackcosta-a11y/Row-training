-- Row Training V217 · Recalcular zonas FC con Karvonen
-- Porcentajes acordados:
-- UT2 55–70% · UT1 70–80% · AT 80–85% · TR 85–95% · AN 95–100% de FC de reserva.
-- Actualiza únicamente el registro más reciente de athlete_metrics de cada usuario
-- que tenga FC máxima y FC de reposo válidas. No crea avisos ni notificaciones.

WITH latest AS (
  SELECT DISTINCT ON (user_id)
    ctid AS row_ctid,
    user_id,
    resting_hr,
    max_hr
  FROM public.athlete_metrics
  WHERE resting_hr IS NOT NULL
    AND max_hr IS NOT NULL
    AND max_hr > resting_hr
  ORDER BY user_id, recorded_at DESC NULLS LAST, ctid DESC
)
UPDATE public.athlete_metrics AS am
SET
  ut2_min = ROUND(latest.resting_hr + (latest.max_hr - latest.resting_hr) * 0.55),
  ut2_max = ROUND(latest.resting_hr + (latest.max_hr - latest.resting_hr) * 0.70),
  ut1_min = ROUND(latest.resting_hr + (latest.max_hr - latest.resting_hr) * 0.70),
  ut1_max = ROUND(latest.resting_hr + (latest.max_hr - latest.resting_hr) * 0.80),
  at_min  = ROUND(latest.resting_hr + (latest.max_hr - latest.resting_hr) * 0.80),
  at_max  = ROUND(latest.resting_hr + (latest.max_hr - latest.resting_hr) * 0.85),
  tr_min  = ROUND(latest.resting_hr + (latest.max_hr - latest.resting_hr) * 0.85),
  tr_max  = ROUND(latest.resting_hr + (latest.max_hr - latest.resting_hr) * 0.95),
  an_min  = ROUND(latest.resting_hr + (latest.max_hr - latest.resting_hr) * 0.95),
  an_max  = ROUND(latest.resting_hr + (latest.max_hr - latest.resting_hr) * 1.00)
FROM latest
WHERE am.ctid = latest.row_ctid;
