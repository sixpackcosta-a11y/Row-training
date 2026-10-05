-- V580 · Dos arreglos:
-- 1) Las sesiones INDIVIDUALES (plan de una o varias remeras concretas) nunca deben ser evento.
--    Se les quita la marca de evento. Los entrenamientos no se borran ni cambian.
-- 2) El jueves 15 de octubre de Veteranas (el que se recuperó con el 43) vuelve a ser evento, con
--    las MISMAS opciones que el evento del jueves 8 (hora, encuentro, invitación, plazas...).
-- Se puede ejecutar más de una vez sin problema.

-- 1) Quitar "evento" a las sesiones individuales
update training_sessions
set is_event = false, updated_at = now()
where is_event = true and target_user_ids is not null;

-- 2) Copiar la configuración de evento del jueves 8 al jueves 15 (Veteranas, misma clase de sesión)
do $$
declare
  src record;
  dst_id bigint;
  cols text[] := array['is_event','event_name','event_time','meet_time','end_time','location','max_participants',
                       'cover_url','reminder_hours_before','default_status','chat_enabled','responses_visibility',
                       'rsvp_open_days_before','rsvp_open_time','created_by'];
  c text; sets text := '';
begin
  select id, session_type into src from training_sessions
  where team_code = 'veteranas' and session_date::date = date '2026-10-08'
    and is_event = true and target_user_ids is null
  order by id limit 1;
  if src.id is null then raise notice 'El jueves 8 no tiene evento de Veteranas: no hay nada que copiar.'; return; end if;

  select id into dst_id from training_sessions
  where team_code = 'veteranas' and session_date::date = date '2026-10-15'
    and target_user_ids is null and session_type = src.session_type
  order by id limit 1;
  if dst_id is null then
    select id into dst_id from training_sessions
    where team_code = 'veteranas' and session_date::date = date '2026-10-15'
      and target_user_ids is null and upper(session_type) <> 'DESC'
    order by id limit 1;
  end if;
  if dst_id is null then raise notice 'El jueves 15 de Veteranas no tiene ningún entrenamiento de equipo: ejecuta antes el 43.'; return; end if;

  foreach c in array cols loop
    if exists (select 1 from information_schema.columns where table_schema='public' and table_name='training_sessions' and column_name=c) then
      sets := sets || format('%I = s.%I, ', c, c);
    end if;
  end loop;
  execute format('update training_sessions t set %s updated_at = now() from training_sessions s where s.id = %s and t.id = %s',
                 sets, src.id, dst_id);
  raise notice 'Evento del 15 creado en la sesión % copiando el del 8 (sesión %).', dst_id, src.id;
end $$;

-- 3) Comprobar el día 15
select id, session_type, title, is_event, event_time, target_user_ids is not null as individual
from training_sessions
where team_code = 'veteranas' and session_date::date = date '2026-10-15'
order by session_type, id;
