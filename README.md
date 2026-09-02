# Row Training V101

Corrección del cumplimiento semanal.

## Cambios
- El porcentaje principal usa **toda la semana planificada**: cada GYM = 1 sesión y cada ERGO = 1 sesión.
- Se añade un segundo dato **Al día** que compara solo las sesiones cuya fecha ya ha llegado.
- Ejemplo: si hay 4 sesiones GYM/ERGO en la semana, ha completado 1 y hasta hoy debían haberse hecho 2, se muestra **25% · 1/4 semana** y **Al día 1/2 · 50%**.
- ERGO registrados como `ERG` o `ERGO` se reconocen correctamente; ErgData/Concept2 sigue contando por fecha.
- MAR no entra en este porcentaje.
- Se mantiene el detalle ejercicio a ejercicio al pulsar Analizar.

## Instalación
No necesita SQL. Copia los archivos del UPDATE sobre el repositorio, commit `V101`, Push origin normal y espera Vercel Ready.
