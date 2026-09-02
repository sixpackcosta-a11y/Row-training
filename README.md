# Row Training V96

Corrección urgente de estabilidad y planificación.

## Cambios
- Corrige el parpadeo entre Acceso e Inicio: la app espera a resolver la sesión antes de mostrar una de las dos pantallas y evita reinicios repetidos por comprobación de versión.
- TEST ERGO por categoría:
  - Veteranas femenino: 1000 m
  - Veteranos masculino: 1000 m
  - Senior masculino: 2000 m
  - Senior femenino: 2000 m
- Primer test: jueves 01/10/2026. Siguientes: 19/11/2026, 07/01/2027, 25/02/2027 y 15/04/2027.
- El martes 29/09 vuelve a ser MAR.
- El remero dispone de una nueva pestaña **Mes** con el mes actual y el siguiente. Puede anticipar GYM, ERGO, tests y competiciones; el contenido MAR sigue oculto.

## Instalación
1. Ejecutar `setup_v96.sql` (o copiar `COPIAR_SQL_V96.txt`) en Supabase SQL Editor.
2. Si devuelve Success, copiar los archivos del UPDATE en la raíz del repositorio.
3. Commit `V96` y Push origin normal.
4. Esperar Vercel Ready.
