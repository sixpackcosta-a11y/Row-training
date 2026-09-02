# Row Training V91

Versión acumulativa: incluye V90 y añade la revisión visual de GYM con fichas de ejecución INICIO / FINAL.

## Instalación
1. Ejecuta `setup_v91.sql` en Supabase → SQL Editor.
2. En iPhone también se incluye `COPIAR_SQL_V91.txt`, con exactamente el mismo SQL, para abrirlo directamente desde Archivos y copiarlo sin instalar ninguna app.
3. Si Supabase devuelve Success, sube los archivos del ZIP UPDATE al repositorio.
4. Commit y Push origin normal. Espera a Vercel Ready.

## V91
- Mantiene la planificación completa 2026–27, simulaciones y semanas de regata de V90.
- Mantiene multiequipo, tiempos MAR con autoformato, biblioteca avanzada y vista semanal del entrenador.
- Fichas visuales GYM revisadas para mostrar INICIO y FINAL en los ejercicios nuevos/principales.
- Nuevas ilustraciones específicas para step-up, curl femoral, gemelos, face pull, bird dog y crunch en polea.
- Se reutilizan las ilustraciones INICIO/FINAL ya existentes y coherentes para zancadas, press de hombro, remo unilateral, farmer carry, planchas y elevación de rodillas.


## CORRECCIÓN SQL
La V91 usa `rower_team_memberships` para las pertenencias de remeros. Se usa un nombre independiente para evitar colisiones con tablas antiguas llamadas `team_memberships` que puedan existir en Supabase. Si una ejecución anterior de V91 falló en la línea de `team_memberships`, vuelve a ejecutar `setup_v91.sql` completo: es acumulativo e idempotente.
