# Row Training V84

Cambios principales respecto a V83:

- Los entrenamientos combinados GYM + ERGO permiten registrar el ERGO manualmente o desde Foto/Galería, igual que un ERGO normal.
- Planificación: en ordenador se puede arrastrar un entrenamiento a otro día; en móvil cada sesión tiene botón Mover como alternativa fiable.
- Planificación: nuevo Plan B · No hay mar, con biblioteca de combinaciones GYM + ERGO que sustituyen una sesión MAR del día seleccionado.
- Biblioteca ERGO: añadidas opciones Senior más largas (45 min, 60 min, 3x15, 2x20 y 4x12) como trabajo opcional, sin cambiar la duración de la planificación oficial. Los enlaces ErgData quedan editables y pueden añadirse después desde la propia Biblioteca ERGO.
- La biblioteca mezcla las sesiones nuevas incluidas en la versión con las ya guardadas en Supabase, para que las nuevas aparezcan sin SQL adicional.
- Se mantiene la sincronización automática Concept2/ErgData introducida en V83.

V84 no requiere SQL nuevo si V83 ya estaba funcionando.
