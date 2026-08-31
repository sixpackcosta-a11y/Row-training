# Row Training V62

V62 parte de V61 e incorpora el flujo de correo y ayuda para nuevas altas.

## Registro
Enlace general:
`https://rowtraining.vercel.app/?registro=1`

La confirmación de correo de Supabase se mantiene activa. Asegúrate de que en:
**Supabase > Authentication > URL Configuration > Site URL** figure:
`https://rowtraining.vercel.app/`

## Email de confirmación de Supabase
Se incluye `email-confirmacion-supabase.html` listo para copiar en:
**Supabase > Authentication > Email Templates > Confirm signup**.

El botón usa `{{ .ConfirmationURL }}`, por lo que conserva la confirmación real de Supabase y después devuelve al usuario a Row Training.

## Email de bienvenida tras aprobación
Al pulsar **Aprobar y asignar** en Altas:
1. se aprueba la solicitud en Supabase;
2. Row Training llama a `/api/registration-welcome`;
3. se envía al remero un correo con:
   - equipo asignado,
   - botón Abrir Row Training,
   - instalación en iPhone/iPad y Android,
   - zonas de FC,
   - GYM,
   - ErgData + Concept2,
   - MAR e Historial.

Si el correo falla, la aprobación NO se deshace. El entrenador ve un aviso indicando el motivo.

### Variables necesarias en Vercel
Ya usada por el proyecto:
- `SUPABASE_SERVICE_ROLE_KEY`

Para enviar emails:
- `RESEND_API_KEY`
- `WELCOME_FROM_EMAIL` (recomendado), por ejemplo `Row Training <app@tudominio.es>`

También se acepta `REGISTRATION_FROM_EMAIL` como remitente de respaldo.

**Importante:** para enviar emails a cualquier remero con Resend, el dominio del remitente debe estar verificado en Resend. `onboarding@resend.dev` sirve principalmente para pruebas limitadas.

El aviso al entrenador de nuevas altas sigue usando opcionalmente:
- `REGISTRATION_NOTIFY_EMAIL`

## Ayuda ampliada
La sección Ayuda y `?guia=1` explican:
- instalación como app,
- Perfil y zonas UT2/UT1/AT/TR/AN,
- registro GYM,
- conexión Concept2,
- flujo Row Training → ErgData → PM5 → Concept2 → Row Training,
- resultados ERGO,
- MAR e Historial.

## Base de datos
V62 no requiere SQL nuevo si `setup_v61.sql` ya fue ejecutado.

## Seguridad
`_concept2-common.js` no está incluido.

## V63 · Recuperación de contraseña
- Botón `He olvidado mi contraseña` en el acceso.
- Envío de recuperación mediante Supabase Auth.
- Pantalla dentro de Row Training para crear y confirmar la nueva contraseña.
- Plantilla `email-restablecer-supabase.html` para Authentication → Email Templates → Reset Password.
- No requiere SQL nuevo.

## V64 — estabilidad Concept2 / ErgData
- Historial ya no sincroniza Concept2 automáticamente al abrirse: carga primero los datos guardados.
- Sincronización Concept2 procesada en lote (hasta 50 resultados en un solo UPSERT) en lugar de consultas secuenciales por entrenamiento.
- Bloqueo contra sincronizaciones simultáneas y timeout para evitar que la interfaz quede esperando indefinidamente.
- Protección frente a carreras de render entre Historial y Perfil.
- Botón Sincronizar ahora muestra estado mientras trabaja.
