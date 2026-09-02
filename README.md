# Row Training V89

Versión de consolidación y limpieza de interfaz posterior a V88.

## Instalación

1. Ejecuta **`setup_v89.sql`** en Supabase → SQL Editor. Es acumulativo e idempotente; sustituye los ajustes necesarios de V88 para esta versión.
2. Sube los archivos del ZIP UPDATE a la raíz del repositorio.
3. Commit y **Push origin normal**. No uses force push.
4. Espera a que Vercel marque **Ready**.

## Cambios principales

- Vista **Semana del entrenador** compacta: resumen por día y botón **Ver detalle**, sin meter todos los bloques en siete columnas. En móvil se apila por días.
- Limpieza de **Equipo / Roles**: contadores separados, mejor sangría, “Equipo técnico” en castellano, códigos internos discretos y nombres/correos en lugar de UUID cuando están disponibles.
- Bibliotecas MAR/GYM con filtros responsivos que ya no se montan sobre el buscador, contadores visuales y opción **Solo favoritas**.
- Corregida la categoría **Viradas / ciaboga**, que antes podía quedar dentro de Técnica por contener la palabra “técnica”.
- GYM: duración estimada visible y recalculada al añadir, quitar o modificar ejercicios.
- GYM: nombres de grupos más comprensibles (espalda y bíceps, pecho/hombro/tríceps, manos/antebrazos) con iconos discretos para no sobrecargar la pantalla.
- Biblioteca compartida: **Favorita** y **Ocultar para mí** son preferencias personales; **Archivar/Desarchivar** queda solo para el administrador.
- Todas las plantillas base MAR y GYM se guardan también en `training_library`, por lo que el administrador puede archivarlas igual que las creadas posteriormente.
- Cada elemento muestra **autor, fecha y hora**; las plantillas base figuran como **Sistema**.
- Antes de archivar, la app comprueba planificación futura de los equipos que lleva el usuario y avisa dónde se está utilizando. Archivar no modifica sesiones ya planificadas ni históricos.
- Registro MAR móvil: entrada rápida de tiempos sin escribir dos puntos: `523 → 5:23`, `1058 → 10:58`, `58 → 0:58`; teclado numérico, avance a la siguiente serie y diseño de series adaptado a móvil.
- Se mantiene la gestión dinámica de equipos, las altas por equipo, las bibliotecas, ErgData/Concept2 y el resto de funciones previas.

## Archivado

- **Administrador:** puede archivar y desarchivar cualquier elemento, incluido el contenido base del sistema.
- **Entrenadores:** pueden marcar Favorita y Ocultar para mí sin afectar a otros.
- Las archivadas se consultan con el filtro **Archivadas** y pueden recuperarse.
