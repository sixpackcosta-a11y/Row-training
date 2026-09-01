# Row Training V83

Cambios sobre V82:
- Sincronización **automática** de Concept2/ErgData para remeros que ya han conectado su cuenta.
- Se intenta al abrir la app, al volver desde ErgData/otra app y al entrar en **Historial**.
- Historial sigue abriendo primero los datos guardados para no bloquear la navegación; si llegan resultados nuevos se actualiza solo.
- El botón **Sincronizar ahora (manual)** permanece en Perfil como respaldo.
- Protección de 2 minutos entre intentos automáticos para evitar llamadas duplicadas por eventos de foco/visibilidad.
- Añadido control de versión (`version.json`): desde V83, cuando se despliegue una versión futura en la misma URL, la app detectará la nueva versión al volver al primer plano y recargará automáticamente.
- Mantiene íntegramente las correcciones de V82 para avisos de nuevas altas.

## SQL
V83 **no necesita SQL nuevo** si V82/V81/V70 ya estaban instaladas.

## Vercel
Mantén las variables existentes:
- `ROWTRAINING_GMAIL_USER`
- `ROWTRAINING_GMAIL_APP_PASSWORD`
- `REGISTRATION_NOTIFY_EMAIL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `CONCEPT2_CLIENT_SECRET`

No volver a ejecutar scripts antiguos de planificación.
