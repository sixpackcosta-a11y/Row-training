# Row Training V94 · CORREGIDA

## Corrección importante
La primera V94 intentaba guardar `MIX` en `training_sessions.session_type`, pero la base solo admite `GYM`, `ERG`, `MAR` y `DESC`.

Esta corrección guarda una sesión combinada como **dos registros el mismo día: GYM + ERG**.

## Instalación
1. Ejecuta `setup_v94.sql` (o copia `COPIAR_SQL_V94.txt`) en Supabase SQL Editor.
2. Debe devolver Success.
3. Después sube los archivos del UPDATE a GitHub y haz Push origin normal.

La V94 corregida mantiene MAR martes/domingo, tests ERGO 2000 m, semanas de regata y la duración objetivo de GYM elegida por el entrenador.
