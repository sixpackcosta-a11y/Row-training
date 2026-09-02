# Row Training V92

Corrección de biblioteca GYM centrada en categorías múltiples y agarre.

## Qué corrige
- Farmer carry no había desaparecido: estaba etiquetado como agarre + core, pero la UI solo lo mostraba en la primera categoría coincidente. V92 permite que un ejercicio aparezca en todas las categorías que le corresponden sin duplicar la fila en Supabase.
- Añade 7 ejercicios específicos de agarre más Farmer carry: dead hang, pinza con discos, toalla en barra, curl de muñeca, curl inverso, extensiones de dedos y sujeción isométrica.
- Añade 3 sesiones completas: Agarre + core, Agarre + tirón y Bloque corto de agarre.
- Incluye ilustraciones INICIO / FINAL para el bloque de agarre.

## Instalación
1. Ejecuta `setup_v92.sql` (o copia `COPIAR_SQL_V92.txt`) en Supabase SQL Editor.
2. Si devuelve Success, copia los archivos del ZIP UPDATE a la raíz del repositorio.
3. Commit y Push origin normal.
