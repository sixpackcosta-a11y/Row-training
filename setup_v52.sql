-- Row Training V52 · amplía biblioteca GYM con ejercicios acordados
-- Ejecutar después de setup_v50.sql. No modifica resultados históricos.
insert into public.training_library(kind,name,content)
select * from (values
 ('GYM','Remo en tabla / remo tumbado','3×8–12 · descanso 75–90 s. Tirón principal con pecho apoyado; control y pausa al final.'),
 ('GYM','Carrera','10–20 min según fase. Principalmente base/acondicionamiento; ritmo cómodo, sin fatiga residual.'),
 ('GYM','Escaleras','6×30–45 s · recuperación 60–75 s. Calidad de apoyo y ritmo; bajar andando.'),
 ('GYM','Burpees','3×8–10 · descanso 60–75 s. Acondicionamiento puntual, técnica controlada, nunca al fallo.'),
 ('GYM','Salto al cajón','3×5 · descanso 90–120 s. Potencia: pocas repeticiones, máxima calidad y recuperación completa.')
) as v(kind,name,content)
where not exists (select 1 from public.training_library t where t.kind=v.kind and t.name=v.name);

-- Añade una plantilla corta y utilizable (~55–60 min con calentamiento/vuelta a la calma).
insert into public.training_library(kind,name,content)
select 'GYM','Potencia + acondicionamiento','Calentamiento 8–10 min\nSalto al cajón · 3×5 · rec 90–120 s\nRemo en tabla / remo tumbado · 3×8–12 · rec 75–90 s\nEscaleras · 6×30–45 s · rec 60–75 s\nBurpees · 3×8–10 · rec 60–75 s\nCarrera · 10–15 min suave\nPallof press · 2×10/lado · rec 45–60 s\nVuelta a la calma hasta completar aprox. 55–60 min'
where not exists (select 1 from public.training_library where kind='GYM' and name='Potencia + acondicionamiento');
