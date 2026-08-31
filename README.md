# Row Training V61

Versión completa que incluye todo V60 (registro público de remeros, Altas y guía) y la nueva estructura profesional GYM/ERGO.

## No necesitas V60
Si no llegaste a subir ni ejecutar V60, usa directamente V61.

### Supabase
Ejecuta **solo `setup_v61.sql`**. Incluye:
- altas de remeros y aprobación por entrenador,
- enlaces de invitación,
- estructura semanal GYM/ERGO de septiembre a mayo,
- martes conjunto GYM + ERGO por grupos,
- segundo estímulo ERGO con progresión de temporada,
- primera semana MAR cerrada con bloques concretos.

### Estructura base
- Veteran@s: martes MIX GYM+ERGO, jueves MAR, viernes GYM, sábado ERGO (según fase), domingo MAR.
- Senior: lunes GYM hasta enero, martes MIX GYM+ERGO, jueves MAR, viernes GYM, sábado ERGO (según fase), domingo MAR.
- Desde febrero baja el volumen de fuerza y el segundo ERGO pasa a ser menos frecuente.
- En abril-mayo se prioriza MAR y frescura.

### Martes conjunto
Dos grupos:
1. GYM 25–28 min
2. ERGO 25–28 min
Después intercambian.

ERGO del martes: UT2 2×10 min @20 ppm, rec 3 min.

## Registro
Enlace general: `https://rowtraining.vercel.app/?registro=1`
En el panel **Altas** el entrenador puede copiar enlaces por equipo, aprobar y asignar remeros.

El email de aviso es opcional y requiere configurar Resend en Vercel para `api/registration-notify.js`.
