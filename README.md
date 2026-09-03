# Row Training V103

## V103 CORREGIDA · novedades
- **TEST ERGO muy visible en calendario**: color violeta intenso + icono 🧪, para identificarlo aunque el texto se corte.
- **Estado ErgData/Concept2** en Gestión de equipos, comparación y ficha individual: punto azul = conectado; gris = sin conectar. Nunca se exponen tokens OAuth.
- **Editar perfil de cualquier remero autorizado** desde Análisis.
- Datos editables: nombre, fecha de nacimiento, altura, peso, FC de reposo, FC máxima, UT2, UT1, AT, TR, AN y notas.
- Botón **Calcular zonas** con Karvonen a partir de FC reposo + FC máxima.
- **Comparar perfiles** por equipo: edad, altura, peso, FC y todas las zonas en una tabla de escritorio y tarjetas en móvil.
- Los datos que faltan aparecen como **Pendiente**, nunca como 0.
- Compatible con **multiequipo**: Análisis usa `rower_team_memberships` y no depende solo del `team_code` antiguo.
- El propio remero también puede guardar su **fecha de nacimiento** desde Perfil.

## Instalación
1. Ejecuta `setup_v103.sql` (o `COPIAR_SQL_V103.txt`) en Supabase SQL Editor.
2. Si devuelve **Success**, copia los archivos del UPDATE a la raíz del repositorio.
3. Commit `V103 corregida` y **Push origin** normal.
4. Espera a Vercel `Ready`.

No uses Force Push.
