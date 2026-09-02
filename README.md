# Row Training V100

Corrección de cumplimiento semanal y diseño móvil.

- Cumplimiento cuenta sesiones: GYM=1, ERGO=1.
- Solo cuenta sesiones cuya fecha ya ha llegado.
- MAR no entra.
- Indicador visual motivacional para el remero.
- Tabla del equipo se convierte en tarjetas en móvil; botón Analizar ya no se sale.
- No requiere SQL nuevo sobre V99.

# Row Training V99

## Corrección principal
- La vista mensual del remero abre GYM, ERGO y TEST con contenido real y ordenado.
- V99 actualiza las sesiones automáticas ya existentes que quedaron con textos genéricos.
- ERGO incluye calentamiento, bloques, recuperación, ppm/zona, vuelta a la calma y RPE.
- GYM incluye ejercicios concretos, dosis, descansos y RIR.
- Las sesiones creadas manualmente por entrenadores no se modifican.
- MAR continúa mostrando solo que existe sesión, sin revelar el contenido.

## Instalación
1. Ejecutar `setup_v99.sql` (o copiar `COPIAR_SQL_V99.txt`) en Supabase SQL Editor.
2. Debe devolver Success.
3. Después copiar los archivos del ZIP UPDATE a la raíz del repositorio.
4. Commit `V99` y Push origin normal.
5. Esperar a Vercel Ready.
