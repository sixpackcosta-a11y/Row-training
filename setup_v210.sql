-- Row Training V210 · limpia avisos duplicados ya creados
-- Conserva el más antiguo de cada aviso idéntico generado para el mismo usuario en el mismo minuto.
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY user_id, COALESCE(type,''), COALESCE(title,''), COALESCE(body,''), COALESCE(url,''), date_trunc('minute', created_at)
           ORDER BY created_at ASC, id ASC
         ) AS rn
  FROM public.app_notifications
)
DELETE FROM public.app_notifications n
USING ranked r
WHERE n.id = r.id
  AND r.rn > 1;
