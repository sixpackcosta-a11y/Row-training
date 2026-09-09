-- Row Training V205
-- Redistribución de ERGO y MAR para evitar repeticiones mecánicas y aprovechar la biblioteca.
-- Conserva IDs. No toca sesiones que ya tengan resultados asociados.
-- Mantiene las regatas del 24/10/2026 y 12/12/2026 y las simulaciones ya previstas.

-- ============================================================
-- 1) ERGO: rotación real de biblioteca
--    - si el mismo día hay GYM para el equipo => bloque corto ~30 min
--    - si es ERGO independiente => sesión completa y progresiva
-- ============================================================
WITH ergo_src AS (
  SELECT
    ts.id,
    ts.team_code,
    ts.session_date::date AS d,
    EXISTS (
      SELECT 1 FROM public.training_sessions g
      WHERE g.team_code=ts.team_code
        AND g.session_date::date=ts.session_date::date
        AND g.session_type='GYM'
    ) AS paired_gym,
    ROW_NUMBER() OVER (
      PARTITION BY ts.team_code,
        EXISTS (
          SELECT 1 FROM public.training_sessions g2
          WHERE g2.team_code=ts.team_code
            AND g2.session_date::date=ts.session_date::date
            AND g2.session_type='GYM'
        )
      ORDER BY ts.session_date, ts.id
    ) - 1 AS n
  FROM public.training_sessions ts
  WHERE ts.session_type='ERG'
    AND ts.team_code IN ('veteranas','senior_m')
    AND ts.session_date BETWEEN DATE '2026-09-15' AND DATE '2027-05-31'
    AND NOT EXISTS (
      SELECT 1 FROM public.workout_logs w
      WHERE w.training_session_id=ts.id AND COALESCE(w.hidden,false)=false
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.concept2_results c
      WHERE c.training_session_id=ts.id AND COALESCE(c.hidden,false)=false
    )
), ergo_plan AS (
  SELECT *,
    CASE
      WHEN paired_gym THEN
        CASE (n % 6)
          WHEN 0 THEN 'UT2 · 2×10'' @20 · rec 3'''
          WHEN 1 THEN 'UT2 · 2×12'' @20 · rec 3'''
          WHEN 2 THEN 'UT1 · 2×1000 m @24 · rec 3'''
          WHEN 3 THEN 'UT1 · 5×500 m @24 · rec 2'''
          WHEN 4 THEN 'UT1 · 2×12'' @22 · rec 3'''
          ELSE 'UT1-AT · 28'' progresivo · 20→28 ppm'
        END
      ELSE
        CASE
          WHEN d <= DATE '2026-10-24' THEN
            CASE (n % 6)
              WHEN 0 THEN 'UT2 · 3×10'' @20 · rec 3'''
              WHEN 1 THEN 'UT2 · 3×12'' @20 · rec 3'''
              WHEN 2 THEN 'UT1 · 4×700 m @24 · rec 2'''
              WHEN 3 THEN 'UT1 · 2×1000 m @24 · rec 3'''
              WHEN 4 THEN 'UT1-AT · 28'' progresivo · 20→28 ppm'
              ELSE 'UT1-AT · 3×(500@22 + 500@24 + 500@26) · rec 4'''
            END
          WHEN d <= DATE '2026-12-12' THEN
            CASE (n % 7)
              WHEN 0 THEN 'UT2 · 3×12'' @20 · rec 3'''
              WHEN 1 THEN 'UT1 · 5×700 m @24 · rec 2'''
              WHEN 2 THEN 'UT1 · 3×1000 m @24 · rec 3'''
              WHEN 3 THEN 'UT1 · 2×12'' @22 · rec 3'''
              WHEN 4 THEN 'UT1-AT · 28'' progresivo · 20→28 ppm'
              WHEN 5 THEN 'UT1-AT · 3×(500@22 + 500@24 + 500@26) · rec 4'''
              ELSE CASE WHEN team_code='senior_m' THEN 'UT1 · 2×2000 m @24 · rec 4''' ELSE 'UT1 · 4×700 m @24 · rec 2''' END
            END
          ELSE
            CASE (n % 8)
              WHEN 0 THEN 'UT2 · 2×10'' @20 · rec 3'''
              WHEN 1 THEN 'UT1 · 4×700 m @24 · rec 2'''
              WHEN 2 THEN 'UT1 · 5×500 m @24 · rec 2'''
              WHEN 3 THEN 'UT1 · 2×1000 m @24 · rec 3'''
              WHEN 4 THEN 'UT1 · 5×700 m @24 · rec 2'''
              WHEN 5 THEN 'UT1 · 3×1000 m @24 · rec 3'''
              WHEN 6 THEN 'UT1-AT · 28'' progresivo · 20→28 ppm'
              ELSE 'UT1-AT · 3×(500@22 + 500@24 + 500@26) · rec 4'''
            END
        END
    END AS new_title
  FROM ergo_src
), ergo_text AS (
  SELECT *,
    CASE new_title
      WHEN 'UT2 · 2×10'' @20 · rec 3''' THEN E'BLOQUE ERGO · 25–28 min\nTRABAJO · 2×10 min @20 ppm · rec 3 min suave\nOBJETIVO · UT2, técnica estable y presión uniforme.'
      WHEN 'UT2 · 2×12'' @20 · rec 3''' THEN E'BLOQUE ERGO · ≈30 min\nTRABAJO · 2×12 min @20 ppm · rec 3 min suave\nOBJETIVO · ampliar tiempo útil en UT2 sin aumentar intensidad.'
      WHEN 'UT1 · 2×1000 m @24 · rec 3''' THEN E'BLOQUE ERGO · 25–30 min\nCALENTAMIENTO · 6 min\nTRABAJO · 2×1000 m @24 ppm · rec 3 min\nOBJETIVO · ritmo controlado y homogéneo.'
      WHEN 'UT1 · 5×500 m @24 · rec 2''' THEN E'BLOQUE ERGO · 25–30 min\nCALENTAMIENTO · 5 min\nTRABAJO · 5×500 m @24 ppm · rec 2 min\nOBJETIVO · trabajo fraccionado con técnica estable.'
      WHEN 'UT1 · 2×12'' @22 · rec 3''' THEN E'BLOQUE ERGO · ≈30 min\nTRABAJO · 2×12 min @22 ppm · rec 3 min\nOBJETIVO · transición UT2→UT1 manteniendo control.'
      WHEN 'UT1-AT · 28'' progresivo · 20→28 ppm' THEN E'BLOQUE ERGO · 28 min\nTRABAJO · 28 min progresivos de 20 a 28 ppm\nOBJETIVO · cambios graduales de frecuencia sin perder longitud.'
      WHEN 'UT2 · 3×10'' @20 · rec 3''' THEN E'CALENTAMIENTO · 8–10 min\nTRABAJO · 3×10 min @20 ppm · rec 3 min\nVUELTA A LA CALMA · 6 min\nOBJETIVO · base aeróbica.'
      WHEN 'UT2 · 3×12'' @20 · rec 3''' THEN E'CALENTAMIENTO · 8 min\nTRABAJO · 3×12 min @20 ppm · rec 3 min\nVUELTA A LA CALMA · 6 min\nOBJETIVO · aumentar volumen aeróbico con técnica estable.'
      WHEN 'UT1 · 4×700 m @24 · rec 2''' THEN E'CALENTAMIENTO · 10 min\nTRABAJO · 4×700 m @24 ppm · rec 2 min\nVUELTA A LA CALMA · 6–8 min\nOBJETIVO · ritmo sostenido por metros.'
      WHEN 'UT1 · 5×700 m @24 · rec 2''' THEN E'CALENTAMIENTO · 10 min\nTRABAJO · 5×700 m @24 ppm · rec 2 min\nVUELTA A LA CALMA · 6–8 min\nOBJETIVO · resistencia específica controlada.'
      WHEN 'UT1 · 3×1000 m @24 · rec 3''' THEN E'CALENTAMIENTO · 10 min\nTRABAJO · 3×1000 m @24 ppm · rec 3 min\nVUELTA A LA CALMA · 6–8 min\nOBJETIVO · resistencia específica por metros.'
      WHEN 'UT1 · 2×2000 m @24 · rec 4''' THEN E'CALENTAMIENTO · 10 min\nTRABAJO · 2×2000 m @24 ppm · rec 4 min\nVUELTA A LA CALMA · 6–8 min\nOBJETIVO · volumen específico Senior; no convertir en test.'
      WHEN 'UT1-AT · 3×(500@22 + 500@24 + 500@26) · rec 4''' THEN E'CALENTAMIENTO · 10 min\nTRABAJO · 3 bloques de 500 m @22 + 500 m @24 + 500 m @26 · rec 4 min\nVUELTA A LA CALMA · 6–8 min\nOBJETIVO · progresar dentro de cada bloque sin romper técnica.'
      ELSE E'ERGO · sesión de biblioteca\nOBJETIVO · trabajo controlado según fase de temporada.'
    END AS new_content
  FROM ergo_plan
)
UPDATE public.training_sessions ts
SET title=ergo_text.new_title,
    content=ergo_text.new_content,
    updated_at=now()
FROM ergo_text
WHERE ts.id=ergo_text.id;

-- ============================================================
-- 2) MAR: usar más sesiones completas de biblioteca
--    - simulaciones y regatas conocidas quedan fuera
--    - los martes hasta 12/12 conservan la progresión LD de V199
--    - desde 15/12 los martes rotan las 6 plantillas "Martes 60"
--    - resto de días MAR rota 17 sesiones completas de biblioteca
-- ============================================================

-- Aclarar textos de larga distancia existentes: evitar la abreviatura "LD".
UPDATE public.training_sessions ts
SET title = replace(replace(ts.title,'ritmo LD','ritmo larga distancia'),'específico LD','específico larga distancia'),
    content = replace(replace(replace(ts.content,'ritmo LD','ritmo sostenible de larga distancia'),'objetivo LD','objetivo de larga distancia'),'distancia LD','distancia de larga distancia'),
    updated_at=now()
WHERE ts.session_type='MAR'
  AND ts.team_code IN ('veteranas','senior_m')
  AND ts.session_date BETWEEN DATE '2026-09-15' AND DATE '2026-12-12'
  AND NOT EXISTS (SELECT 1 FROM public.sea_results sr WHERE sr.training_session_id=ts.id);

WITH tue AS (
  SELECT ts.id,ts.team_code,ts.session_date::date d,
         ROW_NUMBER() OVER(PARTITION BY ts.team_code ORDER BY ts.session_date,ts.id)-1 AS n
  FROM public.training_sessions ts
  WHERE ts.session_type='MAR'
    AND ts.team_code IN ('veteranas','senior_m')
    AND ts.session_date BETWEEN DATE '2026-12-15' AND DATE '2027-05-31'
    AND EXTRACT(ISODOW FROM ts.session_date::date)=2
    AND NOT EXISTS (SELECT 1 FROM public.sea_results sr WHERE sr.training_session_id=ts.id)
), tue_plan AS (
  SELECT *, CASE (n % 6)
    WHEN 0 THEN 'Martes 60 · técnica + tiempo'
    WHEN 1 THEN 'Martes 60 · series por metros'
    WHEN 2 THEN 'Martes 60 · paladas y potencia técnica'
    WHEN 3 THEN 'Martes 60 · cambios de ritmo'
    WHEN 4 THEN 'Martes 60 · distancia + corrección'
    ELSE 'Martes 60 · continuo con cambios' END AS new_title
  FROM tue
), tue_text AS (
  SELECT *, CASE new_title
    WHEN 'Martes 60 · técnica + tiempo' THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min · 16–20 ppm progresivo\nTÉCNICA CORRECTIVA · 3×5 min a 16–18 ppm · rec 1 min · un foco técnico distinto por serie\nBASE · 2×10 min a 18–20 ppm · rec 2 min · presión uniforme\nSALIDAS · 4×20 paladas · recuperación 60 s\nVUELTA A LA CALMA · 5 min · muy suave'
    WHEN 'Martes 60 · series por metros' THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min · progresivo\nTÉCNICA · 8 min a 16–18 ppm · entrada limpia y coordinación\nSERIES · 4×500 m · ritmo controlado y homogéneo · rec 2 min\nVIRADA-CIABOGA · 4 repeticiones · máxima calidad\nBASE · 10 min a 18–20 ppm · soltar sin perder técnica\nVUELTA A LA CALMA · 5 min · muy suave'
    WHEN 'Martes 60 · paladas y potencia técnica' THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min · progresivo\nTÉCNICA CORRECTIVA · 2×6 min a 16–18 ppm · rec 2 min · secuencia pierna–tronco–brazo\nPALADAS · 6×30 paladas @26–28 ppm · rec 60 s · potencia sin perder longitud\nBASE · 15 min a 18–20 ppm · ritmo estable\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · 5 min · muy suave'
    WHEN 'Martes 60 · cambios de ritmo' THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min · progresivo\nBASE · 3×8 min a 18–20 ppm · rec 2 min · técnica larga\nCAMBIOS · 6×1 min @24–28 ppm intercalados con 1 min suave\nSALIDAS · 4×15 paladas · recuperación 60 s\nVUELTA A LA CALMA · 5 min · muy suave'
    WHEN 'Martes 60 · distancia + corrección' THEN E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min · progresivo\nSERIES · 3×700 m · ritmo sostenido · rec 2–3 min\nTÉCNICA CORRECTIVA · 10 min a 16–18 ppm · corregir el error predominante del equipo\nBASE · 12 min a 18–20 ppm · presión uniforme\nVUELTA A LA CALMA · 5 min · muy suave'
    ELSE E'DURACIÓN OBJETIVO · 55–60 min\nCALENTAMIENTO · 8 min · progresivo\nBASE CONTINUA · 30 min a 18–20 ppm · incluir 5×1 min @24–26 ppm cada 5 min sin parar\nTÉCNICA CORRECTIVA · 8 min a 16–18 ppm · salida de brazos y recuperación controlada\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · 5 min · muy suave' END AS new_content
  FROM tue_plan
)
UPDATE public.training_sessions ts
SET title=tue_text.new_title,content=tue_text.new_content,updated_at=now()
FROM tue_text WHERE ts.id=tue_text.id;

WITH mar_src AS (
  SELECT ts.id,ts.team_code,ts.session_date::date d,
         ROW_NUMBER() OVER(PARTITION BY ts.team_code ORDER BY ts.session_date,ts.id)-1 AS n
  FROM public.training_sessions ts
  WHERE ts.session_type='MAR'
    AND ts.team_code IN ('veteranas','senior_m')
    AND ts.session_date BETWEEN DATE '2026-09-15' AND DATE '2027-05-31'
    AND EXTRACT(ISODOW FROM ts.session_date::date)<>2
    AND ts.session_date::date NOT IN (
      DATE '2026-09-27',DATE '2026-10-11',DATE '2026-10-24',DATE '2026-11-15',DATE '2026-11-29',DATE '2026-12-12'
    )
    AND NOT EXISTS (SELECT 1 FROM public.sea_results sr WHERE sr.training_session_id=ts.id)
), mar_plan AS (
  SELECT *, CASE
    WHEN d IN (DATE '2026-10-22',DATE '2026-12-10') THEN 'Técnica + salidas'
    WHEN d IN (DATE '2026-10-25',DATE '2026-12-13') THEN 'Recuperación + técnica'
    ELSE CASE (n % 17)
      WHEN 0 THEN 'Recuperación + técnica'
      WHEN 1 THEN 'Base + técnica'
      WHEN 2 THEN 'Base aeróbica 3×10'
      WHEN 3 THEN 'Base aeróbica 2×15'
      WHEN 4 THEN 'Base continua larga'
      WHEN 5 THEN 'Técnica + salidas'
      WHEN 6 THEN 'Viradas + salidas'
      WHEN 7 THEN 'Viradas bajo fatiga controlada'
      WHEN 8 THEN 'Técnica + cambios de ritmo'
      WHEN 9 THEN 'Cambios 6×3'
      WHEN 10 THEN 'Ritmo 8×2 min'
      WHEN 11 THEN '4×500 m controlados'
      WHEN 12 THEN '5×500 m progresivos'
      WHEN 13 THEN '4×700 m ritmo sostenido'
      WHEN 14 THEN '5×700 m específico'
      WHEN 15 THEN '3×1000 m resistencia específica'
      ELSE '6×4 min ritmo controlado' END
  END AS new_title
  FROM mar_src
), mar_text AS (
  SELECT *, CASE new_title
    WHEN 'Recuperación + técnica' THEN E'CALENTAMIENTO · 10 min · 16–18 ppm progresivo\nTÉCNICA · 4×5 min a 16–18 ppm · rec 1 min · un foco técnico por bloque\nBASE · 10 min a 18 ppm · palada larga y relajada\nVUELTA A LA CALMA · 8 min · 15–18 ppm muy suave'
    WHEN 'Base + técnica' THEN E'CALENTAMIENTO · 12 min · 16–20 ppm progresivo + movilidad/activación\nTÉCNICA · 3×4 min a 15–18 ppm · rec 1 min · entrada, salida de brazos, core y secuencia\nBASE · 2×7 min a 18–20 ppm · rec 2 min · presión uniforme y palada larga\nVUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave'
    WHEN 'Base aeróbica 3×10' THEN E'CALENTAMIENTO · 12 min · 16–20 ppm progresivo\nBASE · 3×10 min a 18–20 ppm · rec 2 min · ritmo estable y técnica larga\nVUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave'
    WHEN 'Base aeróbica 2×15' THEN E'CALENTAMIENTO · 12 min · 16–20 ppm progresivo\nBASE · 2×15 min a 18–20 ppm · rec 3 min · presión uniforme\nTÉCNICA · 8 min a 16–18 ppm · coordinación\nVUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave'
    WHEN 'Base continua larga' THEN E'CALENTAMIENTO · 12 min · 16–20 ppm progresivo\nBASE · 40 min continuos a 18–20 ppm · palada larga, ritmo conversacional\nVUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave'
    WHEN 'Técnica + salidas' THEN E'CALENTAMIENTO · 12 min · 16–20 ppm progresivo\nTÉCNICA · 3×4 min a 15–18 ppm · rec 1 min\nSALIDAS · 6×15 paladas · recuperación 45–60 s\nBASE · 2×7 min a 18–20 ppm · rec 2 min\nVUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave'
    WHEN 'Viradas + salidas' THEN E'CALENTAMIENTO · 12 min · 16–20 ppm progresivo\nTÉCNICA · 8 min · coordinación y entrada limpia\nVIRADA-CIABOGA · 6 repeticiones · recuperación 60 s · máxima calidad técnica\nSALIDAS · 6×15 paladas · recuperación 45–60 s\nVUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave'
    WHEN 'Viradas bajo fatiga controlada' THEN E'CALENTAMIENTO · 15 min · progresivo + 3 aceleraciones\nSERIES · 4×4 min @24–26 ppm · rec 2 min\nVIRADA-CIABOGA · 8 repeticiones · recuperación 60–75 s · calidad técnica\nSALIDAS · 4×15 paladas · recuperación 60 s\nVUELTA A LA CALMA · 10 min · muy suave'
    WHEN 'Técnica + cambios de ritmo' THEN E'CALENTAMIENTO · 12 min · 16–20 ppm progresivo\nTÉCNICA · 3×4 min a 15–18 ppm · rec 1 min\nPIRÁMIDE · 3 min @20 + 3 min @22 + 3 min @24 + 3 min @26 + 3 min @28 ppm · continua\nSALIDAS · 6×15 paladas · recuperación 45–60 s\nVUELTA A LA CALMA · 8–10 min · 15–18 ppm muy suave'
    WHEN 'Cambios 6×3' THEN E'CALENTAMIENTO · 12 min · progresivo\nCAMBIOS · 6×3 min alternando 2 min @20–22 + 1 min @26–28 ppm · rec 90 s\nBASE · 10 min @18–20 ppm · técnica estable\nVUELTA A LA CALMA · 8–10 min · muy suave'
    WHEN 'Ritmo 8×2 min' THEN E'CALENTAMIENTO · 15 min · progresivo + 3 aceleraciones\nSERIES · 8×2 min @26–30 ppm · rec 90 s · técnica sólida\nRECUPERACIÓN · 3 min · remo suave\nSALIDAS · 4×15 paladas · recuperación 60 s\nVUELTA A LA CALMA · 10 min · muy suave'
    WHEN '4×500 m controlados' THEN E'CALENTAMIENTO · 15 min · progresivo\nTÉCNICA · 8 min · coordinación\nSERIES · 4×500 m · ppm a decisión del entrenador · rec 2 min\nBASE · 8 min suave-técnico\nVUELTA A LA CALMA · 10 min · muy suave'
    WHEN '5×500 m progresivos' THEN E'CALENTAMIENTO · 15 min · progresivo + 3 aceleraciones\nSERIES · 5×500 m · de controlado a vivo · rec 2 min\nRECUPERACIÓN · 3 min · remo suave\nSALIDAS · 4×15 paladas · recuperación 60 s\nVUELTA A LA CALMA · 10 min · muy suave'
    WHEN '4×700 m ritmo sostenido' THEN E'CALENTAMIENTO · 15 min · progresivo\nSERIES · 4×700 m · ritmo sostenido · rec 2–3 min\nTÉCNICA · 8 min suave · corregir detalles\nVUELTA A LA CALMA · 10 min · muy suave'
    WHEN '5×700 m específico' THEN E'CALENTAMIENTO · 15 min · progresivo + 3 aceleraciones\nSERIES · 5×700 m · ritmo específico controlado · rec 3 min\nRECUPERACIÓN · 3 min · remo suave\nVUELTA A LA CALMA · 10 min · muy suave'
    WHEN '3×1000 m resistencia específica' THEN E'CALENTAMIENTO · 15 min · progresivo\nSERIES · 3×1000 m · ritmo fuerte sostenible · rec 3 min\nBASE · 8 min @18–20 ppm · soltar\nVUELTA A LA CALMA · 10 min · muy suave'
    ELSE E'CALENTAMIENTO · 15 min · progresivo\nSERIES · 6×4 min @24–28 ppm · rec 2 min\nRECUPERACIÓN · 3 min · suave\nVUELTA A LA CALMA · 10 min · muy suave' END AS new_content
  FROM mar_plan
)
UPDATE public.training_sessions ts
SET title=mar_text.new_title,content=mar_text.new_content,updated_at=now()
FROM mar_text WHERE ts.id=mar_text.id;

-- Comprobación resumida: frecuencia de uso tras redistribución.
SELECT session_type,team_code,title,COUNT(*) AS usos
FROM public.training_sessions
WHERE team_code IN ('veteranas','senior_m')
  AND session_date BETWEEN DATE '2026-09-15' AND DATE '2027-05-31'
  AND session_type IN ('ERG','MAR')
GROUP BY session_type,team_code,title
ORDER BY session_type,team_code,usos DESC,title;

-- Fechas protegidas / no reescritas por la rotación general:
-- Simulaciones: 27/09, 11/10, 15/11, 29/11 de 2026.
-- Regatas: 24/10/2026 y 12/12/2026.
