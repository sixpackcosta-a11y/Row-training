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
