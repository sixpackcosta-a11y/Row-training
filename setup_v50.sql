-- Row Training V50 · duración realista MAR/GYM
-- Ejecutar después de setup_v47.sql. Sustituye únicamente sesiones generadas por la planificación base.

-- MAR: sesiones diseñadas para 55–60 min totales. En bloques por metros, la vuelta a la calma completa hasta 60'.
do $$
declare r record; w int; v int; dow int; ph text; t text; c text;
begin
 for r in select id,team_code,session_date,title,content from public.training_sessions
  where session_type='MAR' and session_date between date '2026-09-01' and date '2027-05-31'
    and team_code in ('veteranas','veteranos_m','senior_m','senior_f')
 loop
  w:=floor((r.session_date-date '2026-09-01')/7)::int+1; v:=((w-1)%4)+1; dow:=extract(isodow from r.session_date)::int;
  ph:=case when r.session_date<date '2026-11-01' then 'BASE' when r.session_date<date '2027-01-01' then 'FUERZA' when r.session_date<date '2027-03-01' then 'TRANSFERENCIA' when r.session_date<date '2027-04-15' then 'ESPECIFICO' else 'PUESTA' end;

  if ph='BASE' then
   if dow=4 then
    case v
     when 1 then t:='MAR · Técnica + salidas'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 10 min suave\nTÉCNICA · 3×4 min a 15–18 ppm · rec 1 min (14 min) · salida de brazos + conexión de core\nSALIDAS · 6 repeticiones · 6 min total · salida propia del equipo\nVIRADA-CIABOGA · 6 repeticiones · 6 min total\nBASE · 2×8 min a 18–20 ppm · rec 2 min (18 min)\nVUELTA A LA CALMA · 6 min';
     when 2 then t:='MAR · Técnica + Virada-Ciaboga'; c:='DURACIÓN OBJETIVO · 58–60 min\nCALENTAMIENTO · 10 min\nTÉCNICA · 4×3 min a 16–18 ppm · rec 1 min (15 min)\nVIRADA-CIABOGA · 8 repeticiones · 8 min total · últimas 4 con salida progresiva\nSALIDAS · 5 repeticiones · 5 min total\nBASE · 2×7 min a 18–20 ppm · rec 2 min (16 min)\nVUELTA A LA CALMA · 6 min';
     when 3 then t:='MAR · Fuerza por palada técnica'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 10 min\nTÉCNICA · 8 min a 15–17 ppm\nFUERZA POR PALADA · 4×5 min a 18–20 ppm · rec 2 min (26 min)\nSALIDAS · 5 repeticiones · 5 min total\nVIRADA-CIABOGA · 5 repeticiones · 5 min total\nVUELTA A LA CALMA · 6 min';
     else t:='MAR · Pirámide aeróbica técnica'; c:='DURACIÓN OBJETIVO · 58–60 min\nCALENTAMIENTO · 10 min\nTÉCNICA · 6 min a 16–18 ppm\nPIRÁMIDE CONTINUA · 4 min 18 + 4 min 20 + 4 min 22 + 4 min 20 + 4 min 18 ppm (20 min)\nRECUPERACIÓN · 3 min suave\nSALIDAS · 5 repeticiones · 5 min total\nVIRADA-CIABOGA · 6 repeticiones · 6 min total\nVUELTA A LA CALMA · 8 min'; end case;
   else
    case v
     when 1 then t:='MAR · Base aeróbica + técnica'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 10 min\nBASE · 3×10 min a 18–20 ppm · rec 2 min (34 min)\nTÉCNICA · 6 min baja frecuencia\nSALIDAS · 4 repeticiones · 4 min total\nVIRADA-CIABOGA · 4 repeticiones · 4 min total\nVUELTA A LA CALMA · 2 min';
     when 2 then t:='MAR · Base por metros'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 4×1200 m aeróbicos · rec 2:30 min · ppm a decisión del entrenador\nTÉCNICA · 6 min baja frecuencia\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · completar suave hasta 60 min. Si las series se alargan, reducir la vuelta a la calma, nunca superar 60 min.';
     when 3 then t:='MAR · Pirámide aeróbica'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 10 min\nPIRÁMIDE · 5 min 18 + 5 min 20 + 5 min 22 + 5 min 20 + 5 min 18 ppm (25 min)\nRECUPERACIÓN · 4 min suave\nVIRADA-CIABOGA · 6 repeticiones · 6 min total\nSALIDAS · 5 repeticiones · 5 min total\nTÉCNICA · 5 min\nVUELTA A LA CALMA · 5 min';
     else t:='MAR · Técnica larga + base'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 3×5 min a 15–18 ppm · rec 1 min (17 min)\nBASE · 2×10 min a 18–21 ppm · rec 2 min (22 min)\nSALIDAS · 4 repeticiones · 4 min total\nVIRADA-CIABOGA · 4 repeticiones · 4 min total\nVUELTA A LA CALMA · 5 min'; end case;
   end if;
  elsif ph='FUERZA' then
   if dow=4 then
    case v
     when 1 then t:='MAR · Fuerza por palada + salidas'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 10 min\nFUERZA POR PALADA · 5×4 min a 18–22 ppm · rec 2 min (28 min)\nSALIDAS · 6 repeticiones · 6 min total\nVIRADA-CIABOGA + ACELERACIÓN · 5 repeticiones · 7 min total\nVUELTA A LA CALMA · 9 min';
     when 2 then t:='MAR · Ritmo medio + maniobra'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 4×1000 m a 22–24 ppm · rec 3 min\nVIRADA-CIABOGA · 6 repeticiones · últimas 3 con aceleración\nSALIDAS · 4 repeticiones\nVUELTA A LA CALMA · completar suave hasta 60 min.';
     when 3 then t:='MAR · Pirámide fuerza-resistencia'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 10 min\nPIRÁMIDE CONTINUA · 4 min 20 + 5 min 22 + 6 min 24 + 5 min 22 + 4 min 20 ppm (24 min)\nRECUPERACIÓN · 4 min\nSALIDAS · 6 repeticiones · 6 min\nVIRADA-CIABOGA · 6 repeticiones · 6 min\nTÉCNICA SUAVE · 4 min\nVUELTA A LA CALMA · 6 min';
     else t:='MAR · Salida + 500 m'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSALIDA + 500 m · 6 repeticiones · rec 3 min · progresivas\nVIRADA-CIABOGA · 5 repeticiones\nTÉCNICA · 6 min baja frecuencia\nVUELTA A LA CALMA · completar hasta 60 min.'; end case;
   else
    case v
     when 1 then t:='MAR · Resistencia de fuerza'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 3×10 min a 20–23 ppm · rec 3 min (36 min)\nVIRADA-CIABOGA · 5 repeticiones · 5 min\nSALIDAS · 4 repeticiones · 4 min\nVUELTA A LA CALMA · 5 min';
     when 2 then t:='MAR · 6×700 m ritmo medio'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 6×700 m a 23–25 ppm · rec 2:30 min\nVIRADA-CIABOGA · 4 repeticiones\nSALIDAS · 4 repeticiones\nVUELTA A LA CALMA · completar suave hasta 60 min.';
     when 3 then t:='MAR · 3×1500 m progresivos'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 3×1500 m · controlado / medio / medio-alto · rec 3 min\nPPM · entrenador según calidad técnica\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · completar suave hasta 60 min.';
     else t:='MAR · Técnica + 4×7 min'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 8 min a 15–18 ppm\nSERIES · 4×7 min a 22–24 ppm · rec 2 min (34 min)\nSALIDAS · 4 repeticiones · 4 min\nVIRADA-CIABOGA · 3 repeticiones · 3 min\nVUELTA A LA CALMA · 3 min'; end case;
   end if;
  elsif ph='TRANSFERENCIA' then
   if dow=4 then
    case v
     when 1 then t:='MAR · Salida + aceleración + 600 m'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSALIDAS + ACELERACIÓN · 6 repeticiones · 8 min total\nSERIES · 5×600 m a 25–28 ppm · rec 3 min\nVIRADA-CIABOGA + ACELERACIÓN · 4 repeticiones\nVUELTA A LA CALMA · completar hasta 60 min.';
     when 2 then t:='MAR · Pirámide 22-24-26-28'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 10 min\nPIRÁMIDE CONTINUA · 4 min 22 + 4 min 24 + 4 min 26 + 3 min 28 + 4 min 26 + 4 min 24 (23 min)\nRECUPERACIÓN · 4 min\nSALIDAS · 5 repeticiones · 5 min\nVIRADA-CIABOGA · 6 repeticiones · 6 min\nBASE SUAVE · 6 min\nVUELTA A LA CALMA · 6 min';
     when 3 then t:='MAR · 8×400 m calidad'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 8×400 m a 26–29 ppm · rec 2 min\nCada 2 series · 1 Virada-Ciaboga técnica\nSALIDAS · 4 repeticiones\nVUELTA A LA CALMA · completar hasta 60 min.';
     else t:='MAR · Técnica específica + 4×5 min'; c:='DURACIÓN OBJETIVO · 58–60 min\nCALENTAMIENTO · 10 min\nTÉCNICA · 7 min\nSERIES · 4×5 min a 26–28 ppm · rec 3 min (29 min)\nSALIDAS · 5 repeticiones · 5 min\nVIRADA-CIABOGA + ACELERACIÓN · 4 repeticiones · 5 min\nVUELTA A LA CALMA · 4 min'; end case;
   else
    case v
     when 1 then t:='MAR · 4×1000 m progresivos'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 4×1000 m · medio a alto · rec 3 min\nPPM · entrenador según tripulación\nVIRADA-CIABOGA · 4 repeticiones\nSALIDAS · 4 repeticiones\nVUELTA A LA CALMA · completar hasta 60 min.';
     when 2 then t:='MAR · Ritmo + Virada-Ciaboga'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\n3 BLOQUES · 700 m medio + Virada-Ciaboga + 500 m alto · rec 4 min\nSALIDAS · 5 repeticiones\nVUELTA A LA CALMA · completar hasta 60 min.';
     when 3 then t:='MAR · 10×1 min alto / 1 min control'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 10 min\nCAMBIOS · 10×(1 min alto 28–31 ppm + 1 min control 20–22 ppm) (20 min)\nBASE · 10 min a 20–22 ppm\nSALIDAS · 6 repeticiones · 6 min\nVIRADA-CIABOGA · 6 repeticiones · 6 min\nVUELTA A LA CALMA · 8 min';
     else t:='MAR · 6×500 m + salidas'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 6×500 m a 27–30 ppm · rec 3 min\nSALIDAS · 6 repeticiones\nVIRADA-CIABOGA + ACELERACIÓN · 4 repeticiones\nVUELTA A LA CALMA · completar hasta 60 min.'; end case;
   end if;
  elsif ph='ESPECIFICO' then
   if dow=4 then
    case v
     when 1 then t:='MAR · Salidas + 6×350 m'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSALIDAS · 6 repeticiones completas · 7 min\nSERIES · 6×350 m a ritmo competición · rec 3 min\nVIRADA-CIABOGA · 5 repeticiones específicas\nVUELTA A LA CALMA · completar hasta 60 min.';
     when 2 then t:='MAR · 4×700 m específico'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 4×700 m ritmo específico · rec 4 min\nPPM · entrenador según tripulación\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA + ACELERACIÓN · 4 repeticiones\nVUELTA A LA CALMA · completar hasta 60 min.';
     when 3 then t:='MAR · 8×250 m velocidad técnica'; c:='DURACIÓN MÁXIMA · 58–60 min\nCALENTAMIENTO · 10 min\nSERIES · 8×250 m alta calidad · rec 2:30 min\nSALIDAS · 5 repeticiones\nVIRADA-CIABOGA · 5 repeticiones\nBASE SUAVE · 8 min\nVUELTA A LA CALMA · completar hasta 60 min.';
     else t:='MAR · Pirámide específica'; c:='DURACIÓN OBJETIVO · 60 min\nCALENTAMIENTO · 10 min\nPIRÁMIDE · 2 min 24 + 2 min 26 + 2 min 28 + 2 min 30 + 2 min 28 + 2 min 26 · 2 vueltas · rec 4 min (28 min)\nSALIDAS · 5 repeticiones · 5 min\nVIRADA-CIABOGA · 5 repeticiones · 5 min\nBASE SUAVE · 6 min\nVUELTA A LA CALMA · 6 min'; end case;
   else
    case v
     when 1 then t:='MAR · Simulación por bloques'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\n3 BLOQUES · salida + 500 m específico + Virada-Ciaboga + 500 m específico · rec 5 min\nVUELTA A LA CALMA · completar suave hasta 60 min.';
     when 2 then t:='MAR · 3×1000 m específico'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 3×1000 m específico controlado · rec 5 min\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · completar hasta 60 min.';
     when 3 then t:='MAR · 12×30 s alto / 60 s control'; c:='DURACIÓN OBJETIVO · 58–60 min\nCALENTAMIENTO · 10 min\nCALIDAD · 12×(30 s alto + 60 s control) (18 min)\nBASE · 10 min a 20–22 ppm\nSALIDAS · 6 repeticiones · 6 min\nVIRADA-CIABOGA + ACELERACIÓN · 5 repeticiones · 6 min\nVUELTA A LA CALMA · 8–10 min';
     else t:='MAR · 6×500 m competición'; c:='DURACIÓN MÁXIMA · 60 min\nCALENTAMIENTO · 10 min\nSERIES · 6×500 m ritmo competición · rec 4 min\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 4 repeticiones intensas\nVUELTA A LA CALMA · completar hasta 60 min.'; end case;
   end if;
  else
   if dow=4 then
    case v
     when 1 then t:='MAR · Calidad corta + salidas'; c:='DURACIÓN OBJETIVO · 55–58 min\nCALENTAMIENTO · 10 min\nSALIDAS · 5 repeticiones · 6 min\nSERIES · 4×350 m específico · rec 4 min\nVIRADA-CIABOGA · 4 repeticiones · 5 min\nBASE SUAVE · 10 min\nVUELTA A LA CALMA · completar hasta 55–58 min · terminar fresco';
     when 2 then t:='MAR · Activación específica'; c:='DURACIÓN OBJETIVO · 50–55 min\nCALENTAMIENTO · 10 min\nACTIVACIÓN · 6×1 min específico / 2 min suave (18 min)\nSALIDAS · 4 repeticiones · 5 min\nVIRADA-CIABOGA · 4 repeticiones · 5 min\nBASE SUAVE · 8 min\nVUELTA A LA CALMA · 8 min';
     when 3 then t:='MAR · Técnica + 4×250 m'; c:='DURACIÓN OBJETIVO · 50–55 min\nCALENTAMIENTO · 10 min\nTÉCNICA · 10 min baja frecuencia\nSERIES · 4×250 m calidad · recuperación completa\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · completar hasta 50–55 min';
     else t:='MAR · Puesta a punto'; c:='DURACIÓN OBJETIVO · 45–50 min\nCALENTAMIENTO · 10 min\nTÉCNICA · 8 min\nSALIDAS · 3 repeticiones\nSERIES · 3×2 min ritmo competición · rec 4 min (14 min)\nVIRADA-CIABOGA · 3 repeticiones\nVUELTA A LA CALMA · 10 min · terminar fresco'; end case;
   else
    case v
     when 1 then t:='MAR · Específico controlado'; c:='DURACIÓN MÁXIMA · 55 min\nCALENTAMIENTO · 10 min\nSERIES · 3×700 m específico controlado · rec 5 min\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · completar hasta 55 min';
     when 2 then t:='MAR · Ritmo + recuperación'; c:='DURACIÓN MÁXIMA · 55 min\nCALENTAMIENTO · 10 min\nSERIES · 4×500 m específico · rec 4 min\nBASE SUAVE · 10 min\nSALIDAS · 3 repeticiones\nVIRADA-CIABOGA · 3 repeticiones\nVUELTA A LA CALMA · completar hasta 55 min';
     when 3 then t:='MAR · Simulación reducida'; c:='DURACIÓN MÁXIMA · 50–55 min\nCALENTAMIENTO · 10 min\n2 BLOQUES · salida + 500 m específico + Virada-Ciaboga + 500 m específico · rec 6 min\nBASE SUAVE · 8 min\nVUELTA A LA CALMA · completar hasta 50–55 min';
     else t:='MAR · Activación y técnica'; c:='DURACIÓN OBJETIVO · 45–50 min\nCALENTAMIENTO · 8 min\nTÉCNICA · 10 min baja frecuencia\n4×45 s específico · rec 3 min (12 min)\nSALIDAS · 3 repeticiones\nVIRADA-CIABOGA · 3 repeticiones\nBASE SUAVE · 6 min\nVUELTA A LA CALMA · 6 min · sin fatiga residual'; end case;
   end if;
  end if;
  update public.training_sessions set title=t,content=c,updated_at=now() where id=r.id;
 end loop;
end $$;

-- GYM: la planificación base queda explícitamente acotada a ~60'. El detalle de ejercicios sigue siendo editable por el entrenador.
update public.training_sessions
set content = case
 when session_date < date '2026-11-01' then 'DURACIÓN OBJETIVO · 55–60 min. Calentamiento 8–10 min + 5–6 ejercicios. 3 series por ejercicio; técnica y control; 2–3 repeticiones de margen. Prioridad: piernas/cadena posterior/espalda/core. Vuelta a la calma 5 min.'
 when session_date < date '2027-01-01' then 'DURACIÓN OBJETIVO · 55–60 min. Calentamiento 8–10 min + 5 ejercicios principales/accesorios. Fuerza: principales 3–4 series, accesorios 2–3; 1–2 repeticiones de margen en principales. Vuelta a la calma 5 min.'
 when session_date < date '2027-03-01' then 'DURACIÓN OBJETIVO · 50–60 min. Calentamiento 8–10 min + 4–5 ejercicios. Mantener intensidad y reducir volumen para transferir a MAR/ERGO. Sin fatiga residual importante.'
 when session_date < date '2027-04-15' then 'DURACIÓN OBJETIVO · 45–55 min. Calentamiento 8 min + 4–5 ejercicios. Fuerza de mantenimiento, pocas series y alta calidad. Evitar piernas pesadas cerca de sesiones específicas o regatas.'
 else 'DURACIÓN OBJETIVO · 35–50 min según proximidad a competición. 3–4 ejercicios, volumen bajo, cargas conocidas y ejecución rápida/limpia. Objetivo: mantener fuerza y llegar fresco.'
 end,
 updated_at=now()
where session_type='GYM' and session_date between date '2026-09-01' and date '2027-05-31'
  and team_code in ('veteranas','veteranos_m','senior_m','senior_f');

select team_code, session_type, count(*) sesiones
from public.training_sessions
where session_date between '2026-09-01' and '2027-05-31' and session_type in ('MAR','GYM')
group by team_code,session_type order by team_code,session_type;
