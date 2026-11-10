# Revisión técnica v2 — edición pública

**10 de noviembre de 2026. Derivada del paquete privado de revisión; no es una copia byte a byte.**

## Decisión

No ejecutar `loq-vmin-test.ps1` v1.0.1. La revisión detectó problemas de clasificación, aborto y restauración. La evidencia histórica debe contrastarse con sus originales, no descartarse ni darse por validada por un veredicto automático.

## Orden de lectura

1. [PLAN_TECNICO_Y_CRITERIOS.md](PLAN_TECNICO_Y_CRITERIOS.md): fases, puertas, paradas y entregables.
2. [HALLAZGOS_REVISION_CODIGO.md](HALLAZGOS_REVISION_CODIGO.md): defectos y requisitos de una futura corrección.
3. [VALIDACION.md](VALIDACION.md): qué está comprobado y qué falta validar.
4. [RECOLECCION_V2.ps1](RECOLECCION_V2.ps1): adquisición lógica en vivo experimental; no validada funcionalmente en Windows.
5. [INVESTIGACION_ANTECEDENTES_LENOVO.md](INVESTIGACION_ANTECEDENTES_LENOVO.md): fuentes y límites de la investigación previa.
6. [PROMPT_CONTINUIDAD.md](PROMPT_CONTINUIDAD.md): encargo local.

`validar_logica.py` reproduce ocho escenarios sintéticos de las ramas del clasificador histórico y escribe `PRUEBAS_LOGICAS.json`. No ejecuta PowerShell y no implementa un test activo corregido. `ESTADO_VALIDACION.json` distingue el alcance de las comprobaciones.

## Publicación y privacidad

Se omiten números de caso/orden, nombres, seriales, direcciones, correos corporativos, fechas contractuales particulares, adjuntos y evidencia bruta. El paquete privado anterior y su carpeta `antecedentes_v1` NO se copian al repositorio público. Sus manifiestos SHA-256 tampoco se reutilizan para esta edición: los contenidos son distintos.

La publicación no autoriza adquisición, cambios de configuración, ensayos que puedan colgar el equipo, correos ni merge a main. No se realizó aquí una prueba de hardware ni una validación Windows. La investigación inicial fue directa, no un subagente ejecutado.
