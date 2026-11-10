# Hallazgos de revisión de instrumentos

**10-11-2026. Revisión estática y casos sintéticos, no ejecución sobre la laptop.**

Referencia: `loq-vmin-test.ps1` v1.0.1, commit `889e945f9fee1d6d6f57e938070280779c36460a`, blob `057dd7540f99670759d4761c6c9e867a2c5c83b8`.

Fuente inmutable: https://github.com/bot202102/loq-15arp9-crash-check/blob/889e945f9fee1d6d6f57e938070280779c36460a/loq-vmin-test.ps1

## A. Falso negativo de corrida incompleta

`Write-Report` convierte fases ausentes a enteros (`$b = [int]$tot['B']`). La rama negativa comprueba B=0 y ausencia de crash, pero no exige finalización, existencia/duración de B ni estímulo válido. Una excepción previa a B puede producir NEGATIVE.

**Requisito:** estado explícito por fase y validación fail-closed. Fase ausente o inválida implica INCONCLUSO/ABORTADO. Una corrida válida sin eventos solo permite SIN_REPRODUCCION_EN_ESTA_CORRIDA.

## B. AC desconectado solo interrumpe un bucle

`RunPhase` usa `break` al perder AC. El llamador continúa: si ocurre durante A0, puede aplicar el cap y entrar en B. Una fase interrumpida puede acabar presentada como finalizada.

**Requisito:** propagar aborto al coordinador, comprobar AC antes de escribir y continuamente, restaurar y terminar la corrida sin otro estímulo.

## C. Restauración no garantizada ni comprobada

Las llamadas `powercfg` descartan salida sin comprobar sistemáticamente ExitCode. Tras falla de verificación, `finally` reactiva el plan pero no necesariamente reescribe/verifica ambos valores originales. El mensaje Settings restored no prueba restauración. Finally no protege de apagado abrupto.

**Requisito:** conservar originales, verificar cada retorno, ruta de recuperación explícita, comprobar persistencia y estado efectivo. Mostrar RESTAURACION_FALLIDA si corresponde; no anunciar éxito automático.

## D. Cap inicial no demuestra la exposición de toda B

`PerfMax` mide un contador de rendimiento, no tensión. La condición inicial `pc <= 60` no valida toda la ventana ni cada CPU. Overlays, contadores faltantes o poca actividad pueden invalidar la equivalencia del ensayo.

**Requisito:** telemetría por CPU y validez continua; no equiparar 5 % solicitado con 5 % de frecuencia o voltaje mínimo medido. Rehearsal al 90 % tampoco es garantía eléctrica de inocuidad.

## E. Todo WHEA puede activar una conclusión demasiado específica

Se recupera todo el proveedor y POSITIVE no exige la firma CPU/SMCA/APIC histórica. Un WHEA PCIe puede disparar una conclusión sobre el núcleo.

**Requisito:** conservar todos los originales y clasificar origen/firma antes de atribuir. OTRO_ERROR no es corroboración de CPU. Nunca descartar evidencia porque el decoder falle.

## F. Reinicio no limpio adjudicado prematuramente

La búsqueda Kernel-Power 41 parte de la última muestra sin límite final inequívoco de sesión; puede incorporar otro reinicio posterior. Un cuelgue B sin CPER concordante se convierte en POSITIVE_CRASH.

**Requisito:** Run-ID, sesión/boot, ventana limitada y análisis de bugcheck/volcado; CUELGUE_ASOCIADO no prueba causa Vmin.

## G. Afinidad y topología no verificadas

El C# ignora el retorno de SetThreadAffinityMask; progreso/mismatches son agregados. APIC dividido por hilos por núcleo no sustituye un mapa topológico validado.

**Requisito:** retorno/error Win32, CPU de ejecución y progreso por hilo, hermanos SMT identificados. 8C/16T enumerados no equivalen a todos los núcleos efectivamente probados.

## H. Correlación temporal limitada

Marcas en segundos y consultas inclusivas pueden solapar fronteras; los eventos pueden entregarse tarde. Escoger el último log por mtime puede elegir otra corrida tras mover archivos.

**Requisito:** ruta/Run-ID explícitos, UTC con offset, reloj monotónico, RecordID, deduplicación, originales y tratamiento de fronteras ambiguas. Ventanas de duración/carga distintas no son controles simétricos.

## I. Límites del diagnóstico

LS_V2 localiza una unidad reportante, no una celda L1 concreta dañada. RAM sin ECC de sistema no excluye toda interacción con memoria. WHEA no se limita a errores corregidos; un 0xC000001D aislado no prueba corrupción física. Conservar hipótesis de CPU, regulación/placa, firmware y gestión energética.

## Recolector anterior y borrador v2

La revisión privada del recolector anterior detectó exportaciones descartadas sin verificar retorno/archivo y lectura WHEA con errores silenciados. No se publica ese expediente privado.

El borrador `RECOLECCION_V2.ps1` registra stdout/stderr/ExitCode, exporta EVTX temprano, deriva WHEA de System exportado, distingue ausencias/errores, añade inventarios/políticas y produce ESTADOS.csv, RESUMEN.json y hashes. Es adquisición lógica en vivo, no una operación sin huella ni una imagen de disco.

**Las mejoras escritas NO son validación funcional.** Windows/PowerShell y la laptop siguen pendientes de ensayo. El test activo NO está corregido en esta rama; únicamente se pausa su lanzador CMD y se preserva el original para revisión.

## Casos de aceptación de una futura prueba activa

| Caso | Resultado exigido |
|---|---|
| B no iniciada o contador/cap no verificable | ABORTADO/INCONCLUSO; nunca NEGATIVE |
| B interrumpida sin eventos | INCONCLUSO por duración |
| Pérdida AC en A0 | No aplicar cap; terminar |
| Pérdida AC en B | Restaurar y abortar toda la corrida |
| Escritura powercfg falla | No avanzar; registrar y recuperar |
| Restauración falla | RESTAURACION_FALLIDA visible |
| Lectura WHEA falla | INCONCLUSO, no cero |
| WHEA de otro subsistema | OTRO_ERROR |
| Firma histórica confirmada | FALLO_REPRODUCIDO; detener estímulo |
| Reinicio posterior ajeno | No adjudicar a esta corrida |
| Afinidad/progreso incompletos | Cobertura insuficiente |
| Cambia perfil efectivo durante B | INCONCLUSO por exposición |
| Evento en frontera temporal | Marcar ambiguo |
| Cero eventos con todas las condiciones válidas | SIN_REPRODUCCION_EN_ESTA_CORRIDA |

Los ocho escenarios de `validar_logica.py` modelan solo las ramas seleccionadas del clasificador antiguo. Los resultados son una comparación conceptual, no la implementación ni la aceptación del nuevo coordinador.
