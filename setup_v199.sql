-- Row Training V199
-- MAR de los martes: variedad real + progresión hacia las dos próximas regatas de larga distancia.
-- Regatas que NO se modifican: 24/10/2026 y 12/12/2026.
-- Este script SOLO actualiza sesiones MAR de MARTES de Veteranas/Senior y conserva sus IDs.
-- No toca sesiones con resultados MAR ya registrados.

WITH tue AS (
  SELECT
    ts.id,
    ts.team_code,
    ts.session_date::date AS d,
    CASE
      WHEN ts.session_date::date BETWEEN DATE '2026-09-15' AND DATE '2026-10-20' THEN 'ld1'
      WHEN ts.session_date::date BETWEEN DATE '2026-10-27' AND DATE '2026-12-08' THEN 'ld2'
      ELSE 'short'
    END AS phase,
    (((ts.session_date::date - DATE '2026-12-15') / 7) % 6) AS short_variant
  FROM public.training_sessions ts
  WHERE ts.session_type = 'MAR'
    AND ts.team_code IN ('veteranas','senior_m')
    AND ts.session_date BETWEEN DATE '2026-09-15' AND DATE '2027-05-31'
    AND EXTRACT(ISODOW FROM ts.session_date::date) = 2
    AND NOT EXISTS (
      SELECT 1 FROM public.sea_results sr
      WHERE sr.training_session_id = ts.id
    )
), plan AS (
  SELECT *,
    CASE
      -- BLOQUE 1: hacia 24/10 · LD 3000 VET / 4000 SEN
      WHEN d = DATE '2026-09-15' THEN 'MAR · Técnica + 3×8 min · 55–60 min'
      WHEN d = DATE '2026-09-22' THEN CASE WHEN team_code='senior_m' THEN 'MAR · 3×1000 m · LD progresiva · 55–60 min' ELSE 'MAR · 3×750 m · LD progresiva · 55–60 min' END
      WHEN d = DATE '2026-09-29' THEN 'MAR · Recuperación técnica post-simulación · 55 min'
      WHEN d = DATE '2026-10-06' THEN CASE WHEN team_code='senior_m' THEN 'MAR · 2×1350 m · ritmo LD · 55–60 min' ELSE 'MAR · 2×1000 m · ritmo LD · 55–60 min' END
      WHEN d = DATE '2026-10-13' THEN 'MAR · 3×7 min con cambios de ritmo · 55–60 min'
      WHEN d = DATE '2026-10-20' THEN 'MAR · Activación pre-regata · 6×2 min · 50–55 min'

      -- BLOQUE 2: hacia 12/12 · LD 3000 VET / 4000 SEN
      WHEN d = DATE '2026-10-27' THEN 'MAR · Técnica + recuperación post-regata · 55 min'
      WHEN d = DATE '2026-11-03' THEN CASE WHEN team_code='senior_m' THEN 'MAR · 4×800 m · resistencia LD · 55–60 min' ELSE 'MAR · 4×600 m · resistencia LD · 55–60 min' END
      WHEN d = DATE '2026-11-10' THEN 'MAR · 3×8 min · ritmo LD dentro de base · 55–60 min'
      WHEN d = DATE '2026-11-17' THEN 'MAR · Técnica + paladas post-simulación · 55 min'
      WHEN d = DATE '2026-11-24' THEN CASE WHEN team_code='senior_m' THEN 'MAR · 3×1000 m · ritmo LD · 55–60 min' ELSE 'MAR · 3×750 m · ritmo LD · 55–60 min' END
      WHEN d = DATE '2026-12-01' THEN CASE WHEN team_code='senior_m' THEN 'MAR · 2×1350 m · específico LD · 55–60 min' ELSE 'MAR · 2×1000 m · específico LD · 55–60 min' END
      WHEN d = DATE '2026-12-08' THEN 'MAR · Activación pre-regata · 6×2 min · 50–55 min'

      -- DESPUÉS DE LD: rotación variada orientada progresivamente a 700/1400
      WHEN phase='short' AND short_variant=0 THEN 'MAR · Técnica correctiva + base por tiempo · 55–60 min'
      WHEN phase='short' AND short_variant=1 THEN CASE WHEN team_code='senior_m' THEN 'MAR · 4×700 m · media distancia de regata · 55–60 min' ELSE 'MAR · 4×350 m · media distancia de regata · 55–60 min' END
      WHEN phase='short' AND short_variant=2 THEN 'MAR · Paladas de potencia + salidas · 55–60 min'
      WHEN phase='short' AND short_variant=3 THEN 'MAR · 5×3 min · cambios de ritmo · 55–60 min'
      WHEN phase='short' AND short_variant=4 THEN CASE WHEN team_code='senior_m' THEN 'MAR · 3×1000 m · resistencia específica · 55–60 min' ELSE 'MAR · 3×500 m · resistencia específica · 55–60 min' END
      ELSE 'MAR · Continuo con cambios + técnica · 55–60 min'
    END AS new_title,
    CASE
      WHEN d = DATE '2026-09-15' THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min · 16–20 ppm progresivo\nTÉCNICA · 8 min · ataque limpio + apoyo antes de fuerza\nTRABAJO · 3×8 min a 18–20 ppm · rec 2 min · en cada bloque 2 min finales a 22–24 ppm\nPALADAS · 4×20 paladas a 26 ppm · rec 60 s\nVUELTA A LA CALMA · 5 min\nOBJETIVO · base aeróbica y técnica estable antes de aumentar metros.'
      WHEN d = DATE '2026-09-22' THEN CASE WHEN team_code='senior_m' THEN
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 6 min · secuencia pierna–tronco–brazo\nSERIES · 3×1000 m · rec 2:30 min · ritmo sostenible, último 250 m progresivo\nSALIDAS · 3×20 paladas\nVUELTA A LA CALMA · 5 min\nOBJETIVO · acumular 3000 m de trabajo fraccionado, 75% de la distancia LD senior.'
      ELSE
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 6 min · secuencia pierna–tronco–brazo\nSERIES · 3×750 m · rec 2:30 min · ritmo sostenible, último 200 m progresivo\nSALIDAS · 3×20 paladas\nVUELTA A LA CALMA · 5 min\nOBJETIVO · acumular 2250 m de trabajo fraccionado, 75% de la distancia LD veteranas.' END
      WHEN d = DATE '2026-09-29' THEN E'DURACIÓN OBJETIVO · 55 min\nCALENTAMIENTO · 8 min suave\nTÉCNICA CORRECTIVA · 4×5 min · rec 1 min · ataque, profundidad de pala, final y recuperación\nBASE · 2×8 min a 18–20 ppm · rec 2 min\nVIRADAS · 4 repeticiones de calidad\nVUELTA A LA CALMA · 5 min\nOBJETIVO · recuperar tras simulación y corregir errores observados sin carga alta.'
      WHEN d = DATE '2026-10-06' THEN CASE WHEN team_code='senior_m' THEN
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 6 min · apoyo continuo y sacada limpia\nSERIES · 2×1350 m · rec 4 min · ritmo LD controlado, segunda mitad ligeramente más rápida\nPALADAS · 3×20 a ritmo de salida\nVUELTA A LA CALMA · 5 min\nOBJETIVO · 2700 m de trabajo específico, aproximadamente 2/3 de la distancia LD senior.'
      ELSE
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 6 min · apoyo continuo y sacada limpia\nSERIES · 2×1000 m · rec 4 min · ritmo LD controlado, segunda mitad ligeramente más rápida\nPALADAS · 3×20 a ritmo de salida\nVUELTA A LA CALMA · 5 min\nOBJETIVO · 2000 m de trabajo específico, aproximadamente 2/3 de la distancia LD veteranas.' END
      WHEN d = DATE '2026-10-13' THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 6 min · sincronización y longitud\nTRABAJO · 3×7 min · rec 2 min · 3 min base + 2 min ritmo LD + 2 min base\nCAMBIOS · 4×1 min a 24–26 ppm / 1 min suave\nVUELTA A LA CALMA · 5 min\nOBJETIVO · cambiar ritmo sin romper técnica tras la simulación del 11/10.'
      WHEN d = DATE '2026-10-20' THEN E'DURACIÓN OBJETIVO · 50–55 min\nCALENTAMIENTO · 10 min\nTÉCNICA · 8 min muy limpia\nACTIVACIÓN · 6×2 min a ritmo objetivo LD · rec 2 min muy suave\nSALIDAS · 3×15 paladas · recuperación completa\nVUELTA A LA CALMA · 5 min\nOBJETIVO · activar para la regata del 24/10 sin acumular fatiga.'

      WHEN d = DATE '2026-10-27' THEN E'DURACIÓN OBJETIVO · 55 min\nCALENTAMIENTO · 8 min suave\nTÉCNICA CORRECTIVA · 4×5 min · rec 1 min · seleccionar errores observados en regata\nBASE · 15 min a 18–20 ppm\nVIRADAS · 4 repeticiones suaves y limpias\nVUELTA A LA CALMA · 5 min\nOBJETIVO · recuperación activa y corrección técnica tras la regata del 24/10.'
      WHEN d = DATE '2026-11-03' THEN CASE WHEN team_code='senior_m' THEN
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 6 min\nSERIES · 4×800 m · rec 2:30 min · mantener ritmo homogéneo\nFINAL · 4×20 paladas a 26–28 ppm\nVUELTA A LA CALMA · 5 min\nOBJETIVO · 3200 m de trabajo fraccionado, 80% de la distancia LD senior.'
      ELSE
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 6 min\nSERIES · 4×600 m · rec 2:30 min · mantener ritmo homogéneo\nFINAL · 4×20 paladas a 26–28 ppm\nVUELTA A LA CALMA · 5 min\nOBJETIVO · 2400 m de trabajo fraccionado, 80% de la distancia LD veteranas.' END
      WHEN d = DATE '2026-11-10' THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTRABAJO · 3×8 min · rec 2 min · cada bloque: 4 min base + 2 min ritmo LD + 2 min base\nTÉCNICA · 8 min · profundidad de pala + aceleración final\nSALIDAS · 3×20 paladas\nVUELTA A LA CALMA · 5 min\nOBJETIVO · sostener ritmo LD sin perder longitud ni sincronización.'
      WHEN d = DATE '2026-11-17' THEN E'DURACIÓN OBJETIVO · 55 min\nCALENTAMIENTO · 8 min\nTÉCNICA CORRECTIVA · 3×6 min · rec 1 min · elegir 3 errores predominantes de la simulación\nPALADAS · 6×30 paladas a 24–26 ppm · rec 60 s\nBASE · 12 min a 18–20 ppm\nVUELTA A LA CALMA · 5 min\nOBJETIVO · asimilar la simulación del 15/11 y mejorar técnica bajo carga moderada.'
      WHEN d = DATE '2026-11-24' THEN CASE WHEN team_code='senior_m' THEN
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 6 min\nSERIES · 3×1000 m · rec 2:30 min · segundo y tercer bloque con final progresivo\nVIRADAS · 3 repeticiones de calidad\nVUELTA A LA CALMA · 5 min\nOBJETIVO · 3000 m de trabajo específico, 75% de la distancia LD senior.'
      ELSE
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 6 min\nSERIES · 3×750 m · rec 2:30 min · segundo y tercer bloque con final progresivo\nVIRADAS · 3 repeticiones de calidad\nVUELTA A LA CALMA · 5 min\nOBJETIVO · 2250 m de trabajo específico, 75% de la distancia LD veteranas.' END
      WHEN d = DATE '2026-12-01' THEN CASE WHEN team_code='senior_m' THEN
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 5 min\nSERIES · 2×1350 m · rec 4 min · ritmo LD estable, últimos 300 m progresivos\nSALIDAS · 3×15 paladas\nVUELTA A LA CALMA · 5 min\nOBJETIVO · última carga específica larga antes de la regata del 12/12.'
      ELSE
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 5 min\nSERIES · 2×1000 m · rec 4 min · ritmo LD estable, últimos 250 m progresivos\nSALIDAS · 3×15 paladas\nVUELTA A LA CALMA · 5 min\nOBJETIVO · última carga específica larga antes de la regata del 12/12.' END
      WHEN d = DATE '2026-12-08' THEN E'DURACIÓN OBJETIVO · 50–55 min\nCALENTAMIENTO · 10 min\nTÉCNICA · 8 min muy limpia\nACTIVACIÓN · 6×2 min a ritmo objetivo LD · rec 2 min muy suave\nSALIDAS · 3×15 paladas · recuperación completa\nVUELTA A LA CALMA · 5 min\nOBJETIVO · activar para la regata del 12/12 sin generar fatiga.'

      WHEN phase='short' AND short_variant=0 THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA CORRECTIVA · 3×5 min · rec 1 min · ataque, pasada y salida\nBASE · 2×10 min a 18–20 ppm · rec 2 min\nSALIDAS · 4×20 paladas\nVUELTA A LA CALMA · 5 min\nOBJETIVO · técnica individual + base.'
      WHEN phase='short' AND short_variant=1 THEN CASE WHEN team_code='senior_m' THEN
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nSERIES · 4×700 m · rec 2 min · cada repetición equivale a media distancia de regata senior\nTÉCNICA · 8 min\nVUELTA A LA CALMA · 5 min\nOBJETIVO · ritmo por distancia y control técnico.'
      ELSE
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nSERIES · 4×350 m · rec 2 min · cada repetición equivale a media distancia de regata veteranas\nTÉCNICA · 8 min\nVUELTA A LA CALMA · 5 min\nOBJETIVO · ritmo por distancia y control técnico.' END
      WHEN phase='short' AND short_variant=2 THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 8 min\nPOTENCIA · 8×30 paladas @26–30 ppm · rec 60–75 s\nBASE · 15 min a 18–20 ppm\nSALIDAS · 3×15 paladas\nVUELTA A LA CALMA · 5 min\nOBJETIVO · potencia y aceleración sin perder longitud.'
      WHEN phase='short' AND short_variant=3 THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nTRABAJO · 5×3 min · rec 2 min · alternar 22/24/26 ppm según serie\nTÉCNICA · 10 min · recuperación controlada y sincronización\nBASE · 10 min suave\nVUELTA A LA CALMA · 5 min\nOBJETIVO · tolerar cambios de ritmo manteniendo técnica.'
      WHEN phase='short' AND short_variant=4 THEN CASE WHEN team_code='senior_m' THEN
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nSERIES · 3×1000 m · rec 3 min · ritmo sostenido sin llegar a máxima intensidad\nTÉCNICA · 8 min\nVUELTA A LA CALMA · 5 min\nOBJETIVO · resistencia específica hacia 1400 m.'
      ELSE
        E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nSERIES · 3×500 m · rec 3 min · ritmo sostenido sin llegar a máxima intensidad\nTÉCNICA · 8 min\nVUELTA A LA CALMA · 5 min\nOBJETIVO · resistencia específica hacia 700 m.' END
      ELSE E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min\nCONTINUO · 25 min a 18–20 ppm con 5×1 min a 24–26 ppm repartidos dentro del bloque\nTÉCNICA CORRECTIVA · 10 min · trabajar el error predominante\nVIRADAS · 4 repeticiones\nVUELTA A LA CALMA · 5 min\nOBJETIVO · continuidad aeróbica, cambios internos y técnica.'
    END AS new_content
  FROM tue
)
UPDATE public.training_sessions ts
SET title = plan.new_title,
    content = plan.new_content,
    updated_at = now()
FROM plan
WHERE ts.id = plan.id;

-- Comprobación: SOLO martes MAR modificados.
SELECT team_code, session_date, title
FROM public.training_sessions
WHERE session_type='MAR'
  AND team_code IN ('veteranas','senior_m')
  AND session_date BETWEEN DATE '2026-09-15' AND DATE '2027-05-31'
  AND EXTRACT(ISODOW FROM session_date::date)=2
ORDER BY session_date, team_code;

-- Las regatas de 24/10/2026 y 12/12/2026 no forman parte del UPDATE anterior
-- (son sábado y el filtro exige martes), por lo que sus fechas/calendario quedan intactos.
