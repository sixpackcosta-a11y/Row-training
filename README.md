# Row Training V36

## Qué cambia
- Concept2 queda conectado de forma persistente por remero.
- Renovación automática mediante refresh token.
- Sincronización manual desde Perfil.
- Importación deduplicada por `Concept2 result ID`.
- Historial del remero muestra resultados Concept2/ErgData.
- Preparado el emparejamiento: `matched`, `review`, `unplanned`.
- Cursor de mano en botones/enlaces/elementos interactivos, incluido GYM.
- OCR/manual se mantiene como respaldo.

## Antes de desplegar
1. En Supabase > SQL Editor ejecuta `setup_v36.sql`.
2. En Vercel > Settings > Environment Variables conserva:
   - `CONCEPT2_CLIENT_SECRET`
3. Añade otra variable **Sensitive / Production**:
   - `SUPABASE_SERVICE_ROLE_KEY`
   - Su valor se obtiene en Supabase > Project Settings > API > service_role.
   - NO ponerla en HTML, GitHub ni compartirla por chat.
4. Sube estos archivos a GitHub `Row-training` y haz commit a `main`.
5. Vercel desplegará automáticamente.

## Sobre el emparejamiento
V36 ya tiene la base de emparejamiento y tabla `ergo_intents`.
Para que una sesión pueda emparejarse con alta confianza, la planificación deberá guardar una intención ERGO con fecha y, cuando exista, distancia/tipo esperado. La temporada completa todavía no está cargada en la app; por eso los resultados históricos pueden aparecer inicialmente como "No programado". No se inventa una asociación.

## Seguridad
Los access/refresh tokens se guardan en `concept2_connections`, una tabla sin acceso para `authenticated`/`anon`. Solo las funciones de servidor con `SUPABASE_SERVICE_ROLE_KEY` pueden leerlos.

## V37 · emparejamiento ERGO automático
1. Ejecutar `setup_v37.sql` una vez en Supabase.
2. Al mostrar una sesión ERGO, Row Training crea su intención programada (fecha, código, duración, SPM y tipo).
3. `Sincronizar ahora` o abrir `Historial` importa Concept2 y compara fecha + duración/distancia + SPM + tipo.
4. ≥80%: asociado automáticamente. 60–79%: coincidencia dudosa. <60%: no programado.
5. El botón `Abrir entrenamiento en ErgData` usa `ergdata_url` de la intención. Hasta que el entrenador cargue el enlace compartido, avisa sin inventar una URL.

## V38
- Biblioteca ERGO integrada y editable por entrenador.
- Enlaces ErgData depurados precargados.
- Biblioteca adicional del remero filtrada por equipo/fase.
- Sesiones adicionales se registran como intención `additional` y no sustituyen la programada.
- El ERGO programado 3×10' abre directamente su enlace ErgData.
- Cursor pointer global en controles interactivos.
- Ejecutar `setup_v38.sql` una vez en Supabase.
