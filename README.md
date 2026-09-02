# Row Training V87

Cambios principales respecto a V84:

- Biblioteca del entrenador unificada en tres apartados: **ERGO · MAR · GYM**.
- **Biblioteca MAR** independiente de la planificación:
  - bloques de calentamiento, trabajo, recuperación y vuelta a la calma;
  - tiempos por defecto de 12 min de calentamiento, 2 min de recuperación y 8–10 min de vuelta a la calma, todos editables;
  - creación, edición y reutilización de bloques;
  - creación, edición, duplicado y reutilización de **sesiones MAR completas**.
- En Planificación MAR se puede cargar directamente una sesión completa o construirla con bloques.
- Al guardar un MAR se puede marcar **“Guardar también esta sesión MAR completa en la biblioteca”**.
- **REGISTRO MAR** muestra solo los bloques de trabajo. No pide calentamiento, recuperaciones ni vuelta a la calma. Añade un único campo de observaciones globales de la sesión.
- **Biblioteca GYM** independiente: permite crear y editar ejercicios con nombre, dosis, descanso e indicaciones, y usarlos después al construir una sesión.
- Se mantienen las mejoras de V84: combinados GYM+ERGO con registro ERGO manual/foto, mover sesiones, Plan B por mal estado del mar, sesiones ERGO opcionales largas y sincronización automática Concept2/ErgData.

## SQL

Para la cuenta de entrenador global que ya podía crear elementos de `training_library`, V85 puede funcionar sin SQL nuevo.

Se incluye `setup_v85.sql` para dejar formalizados los permisos de la biblioteca también para entrenadores de equipo. Es recomendable ejecutarlo una vez si se van a dar permisos de edición de biblioteca a otros entrenadores.


## V86
- Biblioteca MAR ampliada con 18 sesiones completas y más bloques.
- Biblioteca GYM ampliada con core, planchas, abdominales, unilateral, agarre y espalda.
- Sesiones GYM completas reutilizables.
- Creador GYM manual o con ayuda por duración, objetivos y carga, con duración estimada en vivo.
- Creador MAR con ayuda por duración, objetivo, carga y parcial medio /500 m para estimar bloques por metros.
- Las propuestas son editables antes de guardarlas.
- Incluye `setup_v86.sql`: ejecútalo una vez para permisos de biblioteca de entrenadores y para permitir que un remero rechazado vuelva a solicitar el alta sin crear otra cuenta.

- Corrige el estado de solicitudes rechazadas: ya no se muestran como pendientes y pueden reactivarse desde la propia app.


## V87
- Los entrenadores de equipo con `team_staff_roles.staff_role = 'coach'` pueden ver, aprobar y rechazar las altas dirigidas a sus propios equipos.
- Un entrenador de equipo no puede aprobar remeros para equipos que no entrena.
- Las solicitudes del enlace general quedan reservadas al entrenador administrador/global para evitar que dos entrenadores se apropien de la misma solicitud.
- Los ayudantes no pueden gestionar altas.
- El correo de bienvenida sigue enviándose tras la aprobación.
- Ejecuta `setup_v87.sql` una vez en Supabase. Es idempotente e incluye también los ajustes SQL necesarios de V86.
