# Row Training V104

## Novedades
- Campana **🔔 Notificaciones** dentro de Row Training, con contador de avisos no leídos.
- **Web Push real** para avisos aunque la PWA esté cerrada (en iPhone requiere Row Training instalada en la pantalla de inicio y permiso de notificaciones).
- **Nueva alta de remero**: crea un aviso interno y envía push al entrenador administrador y al entrenador del equipo solicitado.
- El push funciona **aunque falle Gmail**: el correo queda como canal adicional, no como requisito.
- Botón **Activar notificaciones** desde la campana y botón **Enviar prueba** para comprobar el dispositivo.
- Al tocar una notificación de alta se abre directamente **Altas**.

## Instalación V104
1. Ejecuta `setup_v104.sql` (o `COPIAR_SQL_V104.txt`) en Supabase SQL Editor. Debe dar **Success**.
2. En Vercel > Project > Settings > Environment Variables añade `VAPID_PUBLIC_KEY` y `VAPID_PRIVATE_KEY` usando el archivo privado que te entrego aparte.
3. Copia los archivos del UPDATE a la raíz del repositorio.
4. Commit `V104 notificaciones` y **Push origin** normal.
5. Espera Vercel `Ready`.
6. En el iPhone abre Row Training desde el icono instalado > toca 🔔 > **Activar notificaciones** > Permitir.
7. Pulsa **Enviar prueba**.

**Importante:** el archivo con `VAPID_PRIVATE_KEY` NO se copia al repositorio ni se sube a GitHub. Solo se usa para crear las variables de entorno en Vercel.

No uses Force Push.


## V106 — aviso de activación de notificaciones
- Al primer acceso tras actualizar, cada usuario sin push activo recibe un aviso para activar notificaciones.
- Funciona también para usuarios que ya tenían la PWA instalada.
- El aviso se muestra una vez por usuario/dispositivo en esta versión; si ya está suscrito no aparece.
- En iPhone fuera del modo instalado, explica que debe abrirse desde la pantalla de inicio.
- No añade cambios SQL respecto a V104. Si V104 no se instaló, ejecutar setup_v104.sql y configurar VAPID en Vercel antes de desplegar.


## V106
- Alta de push corregida: la suscripción del propio dispositivo se guarda con el JWT del usuario y RLS, sin depender de SUPABASE_SERVICE_ROLE_KEY.
- Prueba push del propio usuario también funciona sin service role.
- Los avisos de nuevas altas a entrenadores siguen requiriendo SUPABASE_SERVICE_ROLE_KEY en Vercel.


## V107
- Web Push: registro verificado del dispositivo en servidor.
- La prueba diferencia entre dispositivo no registrado y envío rechazado.
- Re-registra la suscripción antes de enviar la prueba.


## V108
- Web Push iPhone: VAPID subject normalizado a https://rowtraining.vercel.app para compatibilidad con Apple Web Push.
- La prueba muestra dispositivos encontrados, enviados y fallidos, con detalle del error.


## V109
- Un único usuario activo por dispositivo push: al cambiar de cuenta, el endpoint se reasigna automáticamente.
- Limpieza de endpoints duplicados y restricción única por endpoint (setup_v109.sql).
- El globo rojo de la campana desaparece cuando hay 0 notificaciones sin leer.


## V111
- Corrige el selector de destinatarios en Notificaciones.
- Cuando se elige “Un equipo”, el campo “Remero” queda oculto como corresponde.
- Cuando se elige “Un remero”, aparece el selector y carga los remeros del equipo elegido.
- No requiere SQL.

## V110
- Envío manual de notificaciones desde la campana para entrenadores: todos sus equipos, un equipo o un remero concreto.
- Cada aviso se guarda dentro de Row Training y también se envía por push a los dispositivos suscritos.
- En el editor de entrenamientos aparece la casilla **Enviar notificación a los remeros**, desmarcada por defecto para evitar avisos por retoques internos.
- Al mover una sesión, cancelar una sesión o aplicar un Plan B, el entrenador puede decidir en ese momento si quiere notificar el cambio.
- No añade SQL nuevo sobre V109. Si aún no se ejecutó `setup_v109.sql`, debe ejecutarse antes del despliegue.
