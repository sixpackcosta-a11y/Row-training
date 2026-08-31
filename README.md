# Row Training V35

Base completa: V34.

## Nuevo: piloto Concept2 / ErgData
- Botón **Conectar Concept2** en el perfil del remero.
- OAuth oficial Authorization Code.
- Scopes: `user:read,results:read`.
- Callback: `https://rowtraining.vercel.app/concept2-callback.html`.
- Función segura Vercel: `/api/concept2-pilot`.
- El Client Secret NO está incluido en ningún archivo.
- La prueba lee el perfil y los 10 últimos resultados de RowErg.
- Los tokens NO se devuelven al navegador ni se guardan todavía.
- Esta V35 es un piloto GO/NO-GO; si funciona, el siguiente paso será persistir la conexión y sincronizar automáticamente con Supabase.

## Antes de probar
En Vercel > Project > Settings > Environment Variables añade:

`CONCEPT2_CLIENT_SECRET` = tu Client Secret de Concept2

Actívalo para Production (y Preview si quieres probar previews) y vuelve a desplegar.

## Se conserva
- Separación Veteranas / Senior masculino.
- MAR jueves y domingo para ambos.
- Alternativas seleccionables y reporte entrenador.
- 21 assets.
- Supabase.
- FC y zonas.
- OCR multifoto.
