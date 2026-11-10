# LOQ 15ARP9 — rama de auditoría posterior al servicio

**Revisión v2, 10-11-2026. No es una prueba de reparación validada.**

La documentación operativa vigente de esta rama comienza en [audit/v2/README.md](audit/v2/README.md). El [plan por puntos](audit/v2/PLAN_TECNICO_Y_CRITERIOS.md) define el orden, las condiciones de avance y las causas de parada.

**No ejecutar la prueba activa v1.0.1.** El lanzador `RUN-VMIN-TEST.cmd` está pausado en esta rama. El archivo PowerShell histórico se conserva para auditoría; no se ha corregido ni autorizado su ejecución directa. Leer los [hallazgos](audit/v2/HALLAZGOS_REVISION_CODIGO.md).

El recolector `audit/v2/RECOLECCION_V2.ps1` es experimental: falta validar sintaxis y funcionamiento en Windows antes de usarlo sobre evidencia. Los escenarios Python son sintéticos; no prueban la laptop.

Para continuar en un entorno local, leer [AGENTS.md](AGENTS.md) y [PROMPT_CONTINUIDAD.md](audit/v2/PROMPT_CONTINUIDAD.md). Preservar primero; no cambiar BIOS, BCD, drivers, energía o actualizaciones sin autorización independiente.

El expediente privado, los correos, los identificadores del caso y los registros brutos no se publican. La investigación de antecedentes no acredita malicia en una intervención concreta.

La versión anterior permanece en el [commit histórico auditado](https://github.com/bot202102/loq-15arp9-crash-check/tree/889e945f9fee1d6d6f57e938070280779c36460a). Las conclusiones automáticas antiguas no sustituyen la revisión de los originales ni prevalecen sobre este protocolo.
