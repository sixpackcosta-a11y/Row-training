-- Row Training V167 · permisos del endpoint de eliminación de usuarios
-- Ejecutar una sola vez en Supabase > SQL Editor.
GRANT USAGE ON SCHEMA public TO service_role;
GRANT SELECT, DELETE ON TABLE public.profiles TO service_role;
GRANT SELECT, DELETE ON TABLE public.rower_team_memberships TO service_role;
GRANT SELECT, DELETE ON TABLE public.team_staff_roles TO service_role;
GRANT SELECT, DELETE ON TABLE public.user_roles TO service_role;
GRANT SELECT, DELETE ON TABLE public.registration_requests TO service_role;
GRANT SELECT, DELETE ON TABLE public.athlete_metrics TO service_role;
GRANT SELECT, DELETE ON TABLE public.workout_logs TO service_role;
GRANT SELECT, DELETE ON TABLE public.gym_exercise_results TO service_role;
GRANT SELECT, DELETE ON TABLE public.ergo_results TO service_role;
GRANT SELECT, DELETE ON TABLE public.concept2_results TO service_role;
GRANT SELECT, DELETE ON TABLE public.concept2_connections TO service_role;
GRANT SELECT, DELETE ON TABLE public.ergo_intents TO service_role;
GRANT SELECT, DELETE ON TABLE public.app_notifications TO service_role;
GRANT SELECT, DELETE ON TABLE public.push_subscriptions TO service_role;
