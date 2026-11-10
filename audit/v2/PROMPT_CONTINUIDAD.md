# Encargo para Work/Codex local

Continúa la auditoría del Lenovo LOQ 15ARP9 con Ryzen 7 7435HS. Trabaja en la rama `audit/post-service-v2-2026-11-10` de `bot202102/loq-15arp9-crash-check`. Lee AGENTS.md y después audit/v2/README.md, PLAN_TECNICO_Y_CRITERIOS.md, HALLAZGOS_REVISION_CODIGO.md y VALIDACION.md. No necesitas publicar identificadores del expediente para trabajar en el código.

El titular informa de una reinstalación de Windows sin sustitución de placa y de una recomendación de bloquear drivers. Son hechos declarados que deben contrastarse con registros y documentación privada, no pruebas automáticas de malicia o de reparación. Recupera el expediente privado únicamente desde la fuente que autorice el titular; no inventes su contenido.

No ejecutes loq-vmin-test.ps1 v1.0.1, tampoco Rehearsal ni su reporte como aceptación. La rama pausa el lanzador, pero el código histórico sigue presente para auditoría. El commit auditado es 889e945f9fee1d6d6f57e938070280779c36460a.

Primero identifica qué acceso real tienes al Windows objetivo. No confundas el contenedor de desarrollo con la laptop, no simules conexión ni delegación. RECOLECCION_V2.ps1 es experimental: valida sintaxis y funcionamiento en un Windows de ensayo antes de adquirir evidencia.

Preserva estado en vivo antes de reiniciar/BIOS. No cambies BCD, firmware, drivers, políticas, energía, seguridad ni BitLocker. Mantén originales en disco externo privado, claves de recuperación fuera del expediente y un registro de fallos de adquisición. No publiques datos brutos, correos, seriales o dumps.

Analiza 8C/16T, topología/APIC real, CPU Sets, afinidad y parking; no asumas APIC/2. Revisa perfiles AC/DC/Lenovo, WU/GPO/MDM, drivers efectivos e instalación. Correo corporativo no demuestra administración de Windows. El 80 % histórico incluía una prueba del usuario: no atribuirlo al técnico sin evidencia.

Revalida WHEA/CPER originales: 101 incluye 31 del ensayo. Separa CPU/SMCA de otros subsistemas. LS_V2, Kernel-Power 41 o 0xC000001D solos no prueban una causa microscópica concreta. Porcentaje de rendimiento no mide voltaje.

Antes de cualquier ensayo activo, corrige instrumentos en copia, supera casos de aceptación/recuperación y solicita autorización expresa. Una corrida incompleta es INCONCLUSA; una válida sin eventos es SIN_REPRODUCCION_EN_ESTA_CORRIDA. Detén al primer error, conserva y no acumules cuelgues.

La investigación pública puede delegarse solo si hay un ejecutor real de subagentes; usa el encargo de INVESTIGACION_ANTECEDENTES_LENOVO.md, sin datos privados ni control del equipo. Distingue fuentes primarias, relatos e hipótesis; busca también explicaciones legítimas.

Entrega por fase: puerta de control, instrumento/hash, datos obtenidos, errores, hallazgos, alternativas y siguiente acción autorizable. No enviar correos, contactar terceros, escribir main, hacer merge ni publicar evidencia sin autorización separada.
