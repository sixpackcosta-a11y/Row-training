# Row Training V88

Versión de consolidación de Row Training para Club de Remo Pedregalejo.

## Importante antes de probar

Ejecuta **una sola vez** `setup_v88.sql` en Supabase → SQL Editor. V88 necesita ese SQL para equipos dinámicos, biblioteca compartida/archivada, preferencias de biblioteca, multimedia GYM, multiselección ERGO y permisos de altas por equipo.

Si no llegaste a ejecutar `setup_v86.sql` o `setup_v87.sql`, no hace falta ejecutarlos por separado: usa directamente `setup_v88.sql`.

## Cambios V88

### Vista de entrenador
- Nueva vista **Semana**, similar a la del remero pero operativa para entrenador.
- Selector de equipo y navegación entre semanas.
- Desde la semana: editar, mover y duplicar sesiones; abrir un día vacío para planificar.
- Ayudantes mantienen vista de seguimiento y registro MAR sin permisos de edición.

### Equipos dinámicos
- Los equipos dejan de estar fijados en el código.
- El administrador puede crear, editar, activar o desactivar equipos en **Equipo / Roles**.
- Los selectores de planificación, altas, biblioteca y vistas se alimentan de la lista de equipos activos.
- Los entrenadores y ayudantes se asignan a equipos dinámicamente.

### Altas
- El administrador/global gestiona todas las altas y las solicitudes generales.
- Un entrenador de equipo puede aprobar o rechazar únicamente altas dirigidas a sus equipos.
- Los ayudantes no gestionan altas.
- Las solicitudes rechazadas pueden reactivarse sin crear otra cuenta.

### Biblioteca compartida
- Las plantillas base del sistema no se eliminan.
- Las plantillas creadas por entrenadores son compartidas y visibles por otros entrenadores.
- El creador puede editar/archivar su contenido; el administrador puede gestionar todo.
- Otros entrenadores pueden duplicar, marcar favorito u ocultar para su vista.
- Se usa **Archivar** en lugar de borrado duro para no romper históricos.
- Se muestra el autor cuando procede.

### Biblioteca MAR
- 18 sesiones completas iniciales más bloques reutilizables.
- Biblioteca agrupada en desplegables: sesiones completas, calentamientos, técnica, base, series/ritmos, salidas, viradas/ciaboga, recuperaciones y vuelta a la calma.
- Buscador, filtros por objetivo/carga/duración, mostrar ocultos y vista compacta/detallada.
- Dos caminos claros al crear sesión: **Crear con ayuda** y **Crear manualmente desde bloques**.
- Constructor visual por tarjetas: editar, quitar de la sesión, reordenar por flechas o arrastre y deshacer el último borrado.
- Estimación de duración en tiempo real; los bloques por metros pueden estimarse con parcial medio objetivo /500 m.
- Calentamiento, recuperación y vuelta a la calma se planifican, pero **Registro MAR solo pide los bloques de trabajo y observaciones**.

### Biblioteca GYM
- Biblioteca ampliada a 28 ejercicios iniciales, incluyendo core, planchas, estabilidad, unilateral, agarre y cadena posterior.
- 8 sesiones completas GYM iniciales.
- Biblioteca agrupada en desplegables por sesiones y grupos de ejercicios.
- Buscador, filtros, vista compacta/detallada, favoritos, ocultar y archivar.
- Dos caminos al crear sesión: **Crear con ayuda** y **Crear manualmente desde ejercicios**.
- Constructor visual: dosis y descanso editables por ejercicio, quitar, reordenar y duración estimada en tiempo real.
- Ficha del ejercicio con imagen personalizada, URL de “Cómo hacerlo” y URL de vídeo.
- Las imágenes personalizadas se suben a Supabase Storage (`gym-media`) y pueden sustituirse o quitarse de la ficha.

### Biblioteca ERGO
- Las fases ya no son texto libre en inglés.
- Multiselección en castellano: **Base, Desarrollo, Precompetición / Específica, Competición y Recuperación**.
- Una sesión ERGO puede asignarse a **Todos los equipos** o a varios equipos concretos.
- Se mantienen enlaces ErgData editables.

### Se mantiene de versiones anteriores
- Sincronización automática Concept2/ErgData al abrir la app y al entrar en Historial, con sincronización manual como respaldo.
- Registro manual/foto para ERGO, también en sesiones combinadas GYM + ERGO.
- Plan B para sustituir MAR por combinados.
- Movimiento de sesiones en planificación.

## Actualización

Para una instalación existente basta con subir los archivos de `Row-training-V88-UPDATE.zip` a la raíz del repositorio, hacer commit y push normal. Vercel desplegará la nueva versión.

No uses force push.

### V88 corregida · Archivado recuperable
- Biblioteca MAR y GYM: selector **Activas / Archivadas**.
- **Archivar** no borra: mueve el elemento a Archivadas.
- En Archivadas, el creador o el administrador pueden pulsar **Desarchivar** para recuperarlo.
- Las plantillas archivadas conservan su histórico y no afectan a sesiones ya realizadas.
