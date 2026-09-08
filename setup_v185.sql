-- Row Training V185
-- Corrige únicamente los MAR de los martes para Veteranas y Senior masculino
-- durante la temporada 2026-27. Mantiene IDs y resultados asociados.

UPDATE public.training_sessions
SET
  title = regexp_replace(title, '90\\s*min', '60 min', 'gi'),
  content = regexp_replace(
    content,
    '(DURACI[ÓO]N\\s+OBJETIVO\\s*[·:\\-]?\\s*)90\\s*min',
    E'\\160 min',
    'gi'
  ),
  updated_at = now()
WHERE session_type = 'MAR'
  AND team_code IN ('veteranas','senior_m')
  AND session_date BETWEEN DATE '2026-09-01' AND DATE '2027-05-31'
  AND EXTRACT(ISODOW FROM session_date::date) = 2
  AND (
    title ~* '90\\s*min'
    OR content ~* 'DURACI[ÓO]N\\s+OBJETIVO\\s*[·:\\-]?\\s*90\\s*min'
  );
