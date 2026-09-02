# Row Training V85

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
