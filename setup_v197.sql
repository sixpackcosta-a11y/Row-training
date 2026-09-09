-- Row Training V197
-- Corrige TODOS los entrenamientos MAR de los MARTES para que la sesión completa
-- sea realmente de aproximadamente 60 minutos (Veteranas y Senior masculino).
-- Mantiene los IDs de las sesiones y no toca resultados registrados.

UPDATE public.training_sessions
SET
  title = regexp_replace(
            regexp_replace(COALESCE(title,''), '(?:65|70|75|80|90)\s*min', '60 min', 'gi'),
            '(?:65|70|75|80|90)\s*[–-]\s*(?:70|75|80|90)\s*min', '55–60 min', 'gi'
          ),
  content = trim(both E'\n' from
    regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            regexp_replace(
              regexp_replace(
                regexp_replace(COALESCE(content,''),
                  '(DURACI[ÓO]N(?:\s+OBJETIVO)?\s*[·:\-]?\s*)(?:\d+\s*[–-]\s*\d+|\d+)\s*min',
                  E'\\155–60 min', 'gi'),
                '(CALENTAMIENTO\s*[·:\-]?\s*)(?:12\s*[–-]\s*15|10\s*[–-]\s*12|8\s*[–-]\s*10)\s*min',
                E'\\18 min', 'gi'),
              '3\s*[×x]\s*6\s*min', '2×6 min', 'gi'),
            '3\s*[×x]\s*10\s*min', '2×10 min', 'gi'),
          '(VIRADAS?[^\n]*?)6\s+repeticiones', E'\\14 repeticiones', 'gi'),
        '(FINAL[^\n]*?)4\s*[×x]\s*20\s+paladas', E'\\13×20 paladas', 'gi'),
      '(VUELTA\s+A\s+LA\s+CALMA\s*[·:\-]?\s*)8\s*min', E'\\15 min', 'gi')
  ),
  updated_at = now()
WHERE session_type = 'MAR'
  AND team_code IN ('veteranas','senior_m')
  AND session_date BETWEEN DATE '2026-09-01' AND DATE '2027-05-31'
  AND EXTRACT(ISODOW FROM session_date::date) = 2;

-- Comprobación de los martes MAR tras la corrección.
SELECT id, team_code, session_date, title, content
FROM public.training_sessions
WHERE session_type='MAR'
  AND team_code IN ('veteranas','senior_m')
  AND session_date BETWEEN DATE '2026-09-01' AND DATE '2027-05-31'
  AND EXTRACT(ISODOW FROM session_date::date)=2
ORDER BY team_code, session_date;
