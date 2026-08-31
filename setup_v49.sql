-- Row Training V49 · sesiones MAR completas y variadas 2026-27
-- Ejecutar DESPUÉS de setup_v47.sql. No borra resultados ni toca sesiones MAR que el entrenador ya haya personalizado.

do $$
declare
  r record;
  n int;
  v int;
  dow int;
  ph text;
  new_title text;
  new_content text;
begin
  for r in
    select id, team_code, session_date, title, content
    from public.training_sessions
    where session_type='MAR'
      and session_date between date '2026-09-01' and date '2027-05-31'
      and team_code in ('veteranas','veteranos_m','senior_m','senior_f')
      and (
        title in ('MAR · Técnica y base','MAR · Técnica + fuerza por palada','MAR · Ritmo + maniobras','MAR · Específico de competición','MAR · Calidad y puesta a punto')
        or content like 'Calentamiento · técnica a baja frecuencia%'
        or content like 'Calentamiento · técnica · salidas%'
        or content like 'Calentamiento · salidas + aceleración%'
        or content like 'Calentamiento · salidas específicas%'
        or content like 'Volumen reducido · técnica limpia%'
      )
    order by team_code, session_date
  loop
    n := floor((r.session_date - date '2026-09-01') / 7)::int + 1;
    v := ((n-1) % 4) + 1;
    dow := extract(isodow from r.session_date)::int;
    ph := case
      when r.session_date < date '2026-11-01' then 'BASE'
      when r.session_date < date '2027-01-01' then 'FUERZA'
      when r.session_date < date '2027-03-01' then 'TRANSFERENCIA'
      when r.session_date < date '2027-04-15' then 'ESPECIFICO'
      else 'PUESTA_A_PUNTO'
    end;

    if ph='BASE' then
      if dow=4 then
        case v
          when 1 then new_title:='MAR · Técnica + salidas'; new_content:='CALENTAMIENTO · 12 min suave\nTÉCNICA · 3×4 min a 15–18 ppm · rec 1 min · salida de brazos + conexión de core\nSALIDAS · 6 repeticiones · recuperación completa · salida propia del equipo\nVIRADA-CIABOGA · 6 repeticiones controladas · alternar lado si procede\nBASE · 3×8 min a 18–20 ppm · rec 2 min · palada larga y limpia\nVUELTA A LA CALMA · 10 min suave';
          when 2 then new_title:='MAR · Técnica + Virada-Ciaboga'; new_content:='CALENTAMIENTO · 10 min suave\nTÉCNICA · 4×3 min a 16–18 ppm · rec 1 min · entrada, apoyo y final\nVIRADA-CIABOGA · 8 repeticiones · 4 técnicas + 4 con salida progresiva\nSALIDAS · 4 repeticiones · recuperación completa\nBASE · 2×12 min a 18–20 ppm · rec 3 min\nVUELTA A LA CALMA · 8–10 min';
          when 3 then new_title:='MAR · Fuerza por palada técnica'; new_content:='CALENTAMIENTO · 12 min\nTÉCNICA · 10 min a 15–17 ppm · máxima longitud útil\nFUERZA POR PALADA · 4×5 min a 18–20 ppm · rec 2 min · presión progresiva sin perder técnica\nSALIDAS · 5 repeticiones técnicas\nVIRADA-CIABOGA · 6 repeticiones\nVUELTA A LA CALMA · 10 min';
          else new_title:='MAR · Base con cambios de ritmo'; new_content:='CALENTAMIENTO · 10 min\nTÉCNICA · 8 min a 16–18 ppm\nPIRÁMIDE CONTINUA · 4 min 18 ppm + 4 min 20 ppm + 4 min 22 ppm + 4 min 20 ppm + 4 min 18 ppm\nRECUPERACIÓN · 4 min suave\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 6 repeticiones\nVUELTA A LA CALMA · 10 min';
        end case;
      else
        case v
          when 1 then new_title:='MAR · Base aeróbica + técnica'; new_content:='CALENTAMIENTO · 10 min\nBASE · 3×10 min a 18–20 ppm · rec 3 min\nTÉCNICA ENTRE BLOQUES · 2 min de palada larga y coordinación\nSALIDAS · 4 repeticiones controladas\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 2 then new_title:='MAR · Base por metros'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 4×1500 m a ritmo aeróbico · ppm a decisión del entrenador · rec 3 min\nTÉCNICA · 8 min baja frecuencia\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · 8 min';
          when 3 then new_title:='MAR · Pirámide aeróbica'; new_content:='CALENTAMIENTO · 10 min\nPIRÁMIDE · 5 min 18 ppm + 5 min 20 ppm + 5 min 22 ppm + 5 min 20 ppm + 5 min 18 ppm · continua\nRECUPERACIÓN · 5 min suave\nVIRADA-CIABOGA · 6 repeticiones\nSALIDAS · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
          else new_title:='MAR · Técnica larga + base'; new_content:='CALENTAMIENTO · 10 min\nTÉCNICA · 3×6 min a 15–18 ppm · rec 2 min · brazos/core/longitud\nBASE · 2×15 min a 18–21 ppm · rec 4 min\nSALIDAS · 5 repeticiones\nVIRADA-CIABOGA · 5 repeticiones\nVUELTA A LA CALMA · 8 min';
        end case;
      end if;

    elsif ph='FUERZA' then
      if dow=4 then
        case v
          when 1 then new_title:='MAR · Fuerza por palada + salidas'; new_content:='CALENTAMIENTO · 12 min\nFUERZA POR PALADA · 5×4 min a 18–22 ppm · rec 2 min · presión alta y técnica estable\nSALIDAS · 6 repeticiones · recuperación completa\nVIRADA-CIABOGA + ACELERACIÓN · 5 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 2 then new_title:='MAR · Bloques medios + maniobra'; new_content:='CALENTAMIENTO · 10 min\nSERIES · 4×1000 m a 22–24 ppm · rec 3 min\nVIRADA-CIABOGA · 8 repeticiones · últimas 4 con aceleración de salida\nSALIDAS · 5 repeticiones\nTÉCNICA · 8 min suave\nVUELTA A LA CALMA · 8 min';
          when 3 then new_title:='MAR · Pirámide de fuerza-resistencia'; new_content:='CALENTAMIENTO · 12 min\nPIRÁMIDE · 4 min 20 + 5 min 22 + 6 min 24 + 5 min 22 + 4 min 20 ppm · continua\nRECUPERACIÓN · 5 min\nSALIDAS · 6 repeticiones\nVIRADA-CIABOGA · 6 repeticiones\nVUELTA A LA CALMA · 10 min';
          else new_title:='MAR · Salidas + 500 m'; new_content:='CALENTAMIENTO · 12 min\nSALIDA + 500 m · 6 repeticiones · ritmo progresivo · rec 3–4 min\nTÉCNICA · 8 min a baja frecuencia\nVIRADA-CIABOGA · 6 repeticiones\nBASE · 12 min continuo suave\nVUELTA A LA CALMA · 8 min';
        end case;
      else
        case v
          when 1 then new_title:='MAR · Resistencia de fuerza'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 3×12 min a 20–23 ppm · rec 3 min · presión por palada constante\nVIRADA-CIABOGA · 6 repeticiones\nSALIDAS · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 2 then new_title:='MAR · 6×700 m ritmo medio'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 6×700 m a 23–25 ppm · rec 2:30–3 min\nVIRADA-CIABOGA · 4 repeticiones\nSALIDAS · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 3 then new_title:='MAR · 3×1500 m progresivos'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 3×1500 m · 1º controlado, 2º medio, 3º medio-alto · rec 4 min\nPPM · las fija el entrenador según calidad técnica\nVIRADA-CIABOGA · 5 repeticiones\nVUELTA A LA CALMA · 10 min';
          else new_title:='MAR · Técnica + 4×8 min'; new_content:='CALENTAMIENTO · 10 min\nTÉCNICA · 10 min a 15–18 ppm\nSERIES · 4×8 min a 22–24 ppm · rec 3 min\nSALIDAS · 5 repeticiones\nVIRADA-CIABOGA · 5 repeticiones\nVUELTA A LA CALMA · 10 min';
        end case;
      end if;

    elsif ph='TRANSFERENCIA' then
      if dow=4 then
        case v
          when 1 then new_title:='MAR · Salida + aceleración + series'; new_content:='CALENTAMIENTO · 12 min\nSALIDAS + ACELERACIÓN · 6 repeticiones · 20–30 paladas de calidad\nSERIES · 5×600 m a 25–28 ppm · rec 3 min\nVIRADA-CIABOGA + ACELERACIÓN · 5 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 2 then new_title:='MAR · Pirámide 22-24-26-28'; new_content:='CALENTAMIENTO · 12 min\nPIRÁMIDE · 4 min 22 + 4 min 24 + 4 min 26 + 3 min 28 + 4 min 26 + 4 min 24 ppm · continua\nRECUPERACIÓN · 5 min\nSALIDAS · 5 repeticiones\nVIRADA-CIABOGA · 6 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 3 then new_title:='MAR · 8×400 m calidad'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 8×400 m a 26–29 ppm · rec 2:30 min\nCada 2 series · 1 Virada-Ciaboga técnica\nSALIDAS · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
          else new_title:='MAR · Técnica específica + 4×5 min'; new_content:='CALENTAMIENTO · 10 min\nTÉCNICA · 8 min\nSERIES · 4×5 min a 26–28 ppm · rec 3 min · último minuto fuerte si la técnica se mantiene\nSALIDAS · 6 repeticiones\nVIRADA-CIABOGA + ACELERACIÓN · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
        end case;
      else
        case v
          when 1 then new_title:='MAR · 4×1000 m progresivos'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 4×1000 m · progresar de ritmo medio a alto · rec 3:30 min\nPPM · entrenador según tripulación\nVIRADA-CIABOGA · 4 repeticiones\nSALIDAS · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 2 then new_title:='MAR · 3 bloques ritmo + maniobra'; new_content:='CALENTAMIENTO · 12 min\n3 BLOQUES · 800 m ritmo medio + Virada-Ciaboga + 500 m ritmo alto · rec 4 min entre bloques\nSALIDAS · 5 repeticiones\nTÉCNICA · 8 min suave\nVUELTA A LA CALMA · 10 min';
          when 3 then new_title:='MAR · 10×1 min alto / 1 min control'; new_content:='CALENTAMIENTO · 12 min\nCAMBIOS · 10×(1 min alto 28–31 ppm + 1 min control 20–22 ppm)\nRECUPERACIÓN · 5 min\nSALIDAS · 6 repeticiones\nVIRADA-CIABOGA · 6 repeticiones\nVUELTA A LA CALMA · 10 min';
          else new_title:='MAR · 6×500 m + salidas'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 6×500 m a 27–30 ppm · rec 3 min\nSALIDAS · 6 repeticiones · recuperación completa\nVIRADA-CIABOGA + ACELERACIÓN · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
        end case;
      end if;

    elsif ph='ESPECIFICO' then
      if dow=4 then
        case v
          when 1 then new_title:='MAR · Salidas + ritmo de competición'; new_content:='CALENTAMIENTO · 12 min\nSALIDAS · 6 repeticiones completas\nSERIES · 6×350 m a ritmo de competición · rec 3–4 min\nVIRADA-CIABOGA · 6 repeticiones a intensidad específica\nVUELTA A LA CALMA · 10 min';
          when 2 then new_title:='MAR · 4×700 m específico'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 4×700 m a ritmo específico · rec 4 min\nPPM · fijadas por el entrenador según tripulación\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA + ACELERACIÓN · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 3 then new_title:='MAR · 8×250 m velocidad técnica'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 8×250 m · alta calidad · rec 2:30–3 min\nSALIDAS · 6 repeticiones\nVIRADA-CIABOGA · 5 repeticiones\nVUELTA A LA CALMA · 10 min';
          else new_title:='MAR · Pirámide específica'; new_content:='CALENTAMIENTO · 12 min\nPIRÁMIDE · 2 min 24 + 2 min 26 + 2 min 28 + 2 min 30 + 2 min 28 + 2 min 26 ppm · 2 vueltas · rec 4 min\nSALIDAS · 5 repeticiones\nVIRADA-CIABOGA · 5 repeticiones\nVUELTA A LA CALMA · 10 min';
        end case;
      else
        case v
          when 1 then new_title:='MAR · Simulación por bloques'; new_content:='CALENTAMIENTO · 12 min\n3 BLOQUES · salida + 500 m específico + Virada-Ciaboga + 500 m específico · rec 5 min\nTÉCNICA · 8 min suave entre bloques si es necesario\nVUELTA A LA CALMA · 10 min';
          when 2 then new_title:='MAR · 3×1000 m específico'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 3×1000 m a ritmo específico controlado · rec 5 min\nSALIDAS · 5 repeticiones\nVIRADA-CIABOGA · 5 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 3 then new_title:='MAR · 12×30 s alto / 60 s control'; new_content:='CALENTAMIENTO · 12 min\nCALIDAD · 12×30 s alto + 60 s control · técnica prioritaria\nRECUPERACIÓN · 5 min\nSALIDAS · 6 repeticiones\nVIRADA-CIABOGA + ACELERACIÓN · 5 repeticiones\nVUELTA A LA CALMA · 10 min';
          else new_title:='MAR · 6×500 m competición'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 6×500 m a ritmo de competición · rec 4 min\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 4 repeticiones intensas\nVUELTA A LA CALMA · 10 min';
        end case;
      end if;

    else
      if dow=4 then
        case v
          when 1 then new_title:='MAR · Calidad corta + salidas'; new_content:='CALENTAMIENTO · 12 min\nSALIDAS · 4–5 repeticiones de máxima calidad\nSERIES · 4×350 m a ritmo específico · rec completa 4 min\nVIRADA-CIABOGA · 4 repeticiones limpias\nVUELTA A LA CALMA · 10 min';
          when 2 then new_title:='MAR · Activación específica'; new_content:='CALENTAMIENTO · 12 min\nACTIVACIÓN · 6×1 min a ritmo específico / 2 min suave\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 3 then new_title:='MAR · Técnica + 4×250 m'; new_content:='CALENTAMIENTO · 10 min\nTÉCNICA · 10 min baja frecuencia\nSERIES · 4×250 m de calidad · recuperación completa\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · 8 min';
          else new_title:='MAR · Puesta a punto'; new_content:='CALENTAMIENTO · 10 min\nTÉCNICA · 8 min\nSALIDAS · 3–4 repeticiones\nSERIES · 3×2 min a ritmo de competición · rec 4 min\nVIRADA-CIABOGA · 3–4 repeticiones\nVUELTA A LA CALMA · 10 min · terminar fresco';
        end case;
      else
        case v
          when 1 then new_title:='MAR · Específico controlado'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 3×700 m a ritmo específico controlado · rec 5 min\nSALIDAS · 4 repeticiones\nVIRADA-CIABOGA · 4 repeticiones\nVUELTA A LA CALMA · 10 min';
          when 2 then new_title:='MAR · Ritmo + recuperación'; new_content:='CALENTAMIENTO · 12 min\nSERIES · 4×500 m a ritmo específico · rec 4 min\nBASE SUAVE · 12 min\nSALIDAS · 3 repeticiones\nVIRADA-CIABOGA · 3 repeticiones\nVUELTA A LA CALMA · 8 min';
          when 3 then new_title:='MAR · Simulación reducida'; new_content:='CALENTAMIENTO · 12 min\n2 BLOQUES · salida + 500 m específico + Virada-Ciaboga + 500 m específico · rec 6 min\nVUELTA A LA CALMA · 12 min';
          else new_title:='MAR · Activación y técnica'; new_content:='CALENTAMIENTO · 10 min\nTÉCNICA · 12 min a baja frecuencia\n4×45 s a ritmo específico · rec 3 min\nSALIDAS · 3 repeticiones\nVIRADA-CIABOGA · 3 repeticiones\nVUELTA A LA CALMA · 10 min · sin fatiga residual';
        end case;
      end if;
    end if;

    update public.training_sessions
       set title=new_title, content=new_content, updated_at=now()
     where id=r.id;
  end loop;
end $$;

select team_code, count(*) as sesiones_mar, count(distinct title) as entrenamientos_mar_distintos
from public.training_sessions
where session_type='MAR' and session_date between '2026-09-01' and '2027-05-31'
group by team_code
order by team_code;
