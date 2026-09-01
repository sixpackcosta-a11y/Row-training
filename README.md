# Row Training V79

Versión completa basada en V78.

Cambios principales:
- Análisis MAR rediseñado: ya no usa un calendario lleno de días; muestra únicamente las sesiones MAR y enseña sus ejercicios.
- La comparativa MAR se hace por ejercicio repetido, aunque ese ejercicio aparezca otro día dentro de una sesión con bloques distintos.
- Las series de un mismo ejercicio se agrupan para comparar su resultado global y se pueden desplegar para revisar serie por serie.
- Botón para eliminar resultados MAR de una sesión con confirmación. Solo elimina resultados, nunca la planificación.
- Cumplimiento semanal por remero: GYM cuenta ejercicio por ejercicio y cada sesión ERGO cuenta como 1. MAR no entra en el porcentaje individual.
- El remero ve su porcentaje de cumplimiento en Semana.
- El entrenador ve una tabla comparativa de cumplimiento semanal de todo el equipo.
- Análisis de remeros con selector directo por nombre y ficha completa, sin tener que localizar al remero por sus ejercicios.
- Los nuevos registros GYM y ERGO guardan también la fecha programada para mejorar el cálculo semanal.

No requiere SQL nuevo sobre V72/V78.
