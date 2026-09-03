-- Row Training V109 - una sola cuenta activa por dispositivo push
-- Ejecutar una vez en Supabase SQL Editor antes de desplegar V109.

-- 1) Conserva la suscripción más reciente cuando un mismo endpoint
-- quedó asociado a varias cuentas (por ejemplo al cambiar de usuario).
delete from public.push_subscriptions a
using public.push_subscriptions b
where a.endpoint = b.endpoint
  and a.id < b.id;

-- 2) Un dispositivo/end-point solo puede pertenecer a una cuenta a la vez.
create unique index if not exists push_subscriptions_endpoint_uq
  on public.push_subscriptions(endpoint);

-- 3) Asegura permisos necesarios.
grant select, insert, update, delete on table public.push_subscriptions to authenticated;
grant select, insert, update, delete on table public.push_subscriptions to service_role;
