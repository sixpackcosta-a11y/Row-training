# Row Training V82

Cambios sobre V81:
- Corrige el aviso de **nueva alta al entrenador** cuando Supabase tiene confirmación de email activada y `signUp` devuelve `session = null`.
- El primer aviso se intenta **inmediatamente al registrarse**, antes de confirmar el correo.
- Tras confirmar el correo se mantiene un **segundo intento** por seguridad.
- `notify_sent_at` se usa como reserva atómica para **evitar avisos duplicados**; si Gmail falla, la reserva se libera para permitir el reintento.
- Mantiene íntegramente las funciones de V81, incluido el panel **Altas** para entrenadores de equipo.

## IMPORTANTE
V82 **no necesita SQL nuevo** si V81/V70 ya estaban instaladas.

Mantén en Vercel estas variables:
- `ROWTRAINING_GMAIL_USER`
- `ROWTRAINING_GMAIL_APP_PASSWORD`
- `REGISTRATION_NOTIFY_EMAIL`
- `SUPABASE_SERVICE_ROLE_KEY`

No volver a ejecutar scripts antiguos de planificación.
