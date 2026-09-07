-- Row Training V141 · permisos mínimos del servidor para asociar resultados
-- Ejecutar UNA VEZ después de setup_v140.sql.

grant select on table public.training_sessions to service_role;
grant select on table public.rower_team_memberships to service_role;
grant select on table public.profiles to service_role;
grant select,update on table public.concept2_results to service_role;
grant select,update on table public.workout_logs to service_role;

-- Comprobación: debe devolver cinco filas con el privilegio solicitado a true.
select 'training_sessions.select' as privilege,
       has_table_privilege('service_role','public.training_sessions','select') as granted
union all select 'rower_team_memberships.select',has_table_privilege('service_role','public.rower_team_memberships','select')
union all select 'profiles.select',has_table_privilege('service_role','public.profiles','select')
union all select 'concept2_results.update',has_table_privilege('service_role','public.concept2_results','update')
union all select 'workout_logs.update',has_table_privilege('service_role','public.workout_logs','update');
