-- V196 · Sesiones compartidas GYM + ERGO: GYM aprox. 30 min
-- Solo toca sesiones GYM que comparten MISMO equipo y fecha con una sesión ERG.
-- No toca sesiones GYM independientes ni resultados registrados.

WITH shared_gym AS (
  SELECT g.id
  FROM public.training_sessions g
  WHERE g.session_type = 'GYM'
    AND g.session_date BETWEEN DATE '2026-09-01' AND DATE '2027-05-31'
    AND EXISTS (
      SELECT 1
      FROM public.training_sessions e
      WHERE e.team_code = g.team_code
        AND e.session_date = g.session_date
        AND e.session_type = 'ERG'
    )
)
UPDATE public.training_sessions g
SET
  title = regexp_replace(
            regexp_replace(COALESCE(g.title,''), '45[–-]50\s*min', '28–30 min', 'gi'),
            '35[–-]40\s*min', '28–30 min', 'gi'
          ),
  content = trim(both E'\n' from
            regexp_replace(
              regexp_replace(
                regexp_replace(
                  regexp_replace(
                    regexp_replace(
                      regexp_replace(COALESCE(g.content,''),
                        'DURACI[ÓO]N(?:\s+OBJETIVO)?\s*[·:-]\s*(?:35[–-]40|40[–-]45|45[–-]50)\s*min',
                        'DURACIÓN OBJETIVO · 28–30 min', 'gi'),
                      'CALENTAMIENTO\s*[·:-]\s*8[–-]10\s*min',
                      'CALENTAMIENTO · 5 min', 'gi'),
                    '3\s*[×x]\s*8[–-]10', '2×8–10', 'gi'),
                  '3\s*[×x]\s*10(?:/lado)?', '2×10', 'gi'),
                '^.*PRESS DE PECHO.*(?:\n|$)', '', 'gim'),
              '^.*DEAD BUG.*(?:\n|$)', '', 'gim')
          ),
  updated_at = now()
WHERE g.id IN (SELECT id FROM shared_gym);

-- Comprobación: debe devolver solo los GYM que comparten día con ERGO.
SELECT g.id, g.team_code, g.session_date, g.title, g.content
FROM public.training_sessions g
WHERE g.session_type='GYM'
  AND g.session_date BETWEEN DATE '2026-09-01' AND DATE '2027-05-31'
  AND EXISTS (
    SELECT 1 FROM public.training_sessions e
    WHERE e.team_code=g.team_code
      AND e.session_date=g.session_date
      AND e.session_type='ERG'
  )
ORDER BY g.team_code, g.session_date;
