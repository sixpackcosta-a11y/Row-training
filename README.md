# Row Training V68

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


## V65 · correo Gmail de Row Training

Los correos propios de la app (aviso de nueva alta y bienvenida tras aprobación) salen ahora por Gmail SMTP usando:

- `ROWTRAINING_GMAIL_USER`
- `ROWTRAINING_GMAIL_APP_PASSWORD`
- `REGISTRATION_NOTIFY_EMAIL` (opcional; si falta, el aviso de alta llega a `ROWTRAINING_GMAIL_USER`)

La contraseña de aplicación debe guardarse solo como variable de entorno de Vercel y nunca incluirse en GitHub.

Los correos de confirmación y recuperación siguen perteneciendo a Supabase Auth. Para que también salgan como Row Training, configura en Supabase Authentication > SMTP la misma cuenta Gmail y pega las plantillas `email-confirmacion-supabase.html` y `email-restablecer-supabase.html`.


## V66
- Corrige el envío de bienvenida tras aprobar un alta (`coach_check_failed`).
- La API usa la sesión autenticada y las políticas RLS de Supabase, sin depender de permisos directos de `service_role` sobre `user_roles`.
- Añade botón **Reenviar bienvenida** en altas revisadas/aprobadas.
- Refuerza el aviso de nueva inscripción con la clave pública de Supabase como fallback.
- No requiere SQL nuevo.

## V67
- Corrige la detección de "Hoy" usando la fecha local real del dispositivo, no el día seleccionado del calendario.
- La semana inicial marca automáticamente el día real (31/08–06/09/2026).
- Corrige las fechas programadas de la semana y evita usar UTC para acciones que dependen del día local.

## V68 · cardio integrado sin perder especificidad
- Incluye íntegramente la corrección V67 de **HOY** con fecha local real.
- Martes conjunto: **GYM 22–25 min + ERGO 25–28 min + 10 min de carrera suave** (aprox. 60–65 min con cambio de grupos).
- Viernes, septiembre-octubre: fuerza + **12–15 min de cardio suave**; el volumen baja progresivamente durante la temporada.
- El cardio es de base: **RPE 3–4/10 y ritmo conversacional**, no una sesión dura añadida.
- Si correr da molestias, se permite **bici o elíptica** con la misma duración/intensidad.
- Se mantienen dos estímulos ERGO semanales en la fase de base: martes corto + sábado principal.
- El editor GYM del entrenador incorpora **Cardio final + duración** para que al editar una sesión no se pierda este bloque.
- Los lunes de fuerza Senior no reciben cardio automático: el bloque aeróbico se concentra en martes/viernes para controlar la fatiga.

### Base de datos
Si `setup_v61.sql` ya está ejecutado, ejecutar solamente `setup_v68.sql`.

## V69 · semanas 1 y 2 cerradas
- Rower `Semana` ya permite navegar 31/8–6/9 y 7/9–13/9.
- Semana 2 cerrada: martes MIX GYM+ERGO+cardio, jueves MAR 60', viernes fuerza global+cardio, sábado UT2 3×12', domingo MAR 60'.
- Senior añade el lunes un GYM-D superior+core sin piernas pesadas para no interferir con el martes.
- ERGO del sábado 12 abre correctamente la sesión 3×12' de ErgData y guarda la intención con su código propio.
- Visuales: en estas dos semanas solo se muestran imágenes que se han dejado como suficientemente claras; el press de pecho sigue sin imagen antes que mostrar una guía dudosa.
- `setup_v69.sql` incluye el ajuste de cardio de V68. Si no ejecutaste `setup_v68.sql`, ejecuta solo `setup_v69.sql` después de V61.

## V70 · aviso automático de nuevas altas

Con confirmación de email activada, Supabase no devuelve una sesión en el momento del registro. Por eso el aviso de alta de V69 podía no enviarse. V70 lo corrige: cuando la remera/remero confirma el correo y vuelve a Row Training, la app envía en segundo plano un aviso al entrenador sin bloquear la interfaz.

- Destinatario: `REGISTRATION_NOTIFY_EMAIL` si existe en Vercel; si no, `ROWTRAINING_GMAIL_USER`.
- El correo incluye nombre, email, equipo invitado y botón para abrir Row Training.
- `notify_sent_at` evita correos duplicados aunque el usuario recargue la app.
- Ejecutar `setup_v70.sql` después de `setup_v69.sql`.
