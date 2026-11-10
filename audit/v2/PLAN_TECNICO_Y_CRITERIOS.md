# Plan técnico de trabajo — Lenovo LOQ 15ARP9

**Versión 2 pública · 10 de noviembre de 2026. Identificadores privados omitidos.**

## Decisión y orden obligatorio

Investigar una anomalía dependiente del estado energético y posibles restricciones posteriores al servicio, sin asumir una reparación acreditada ni intención maliciosa. **La prueba activa v1.0.1 queda fuera de uso hasta corregir y validar los hallazgos.** No se realizaron pruebas sobre la laptop en esta revisión.

Orden: **preservar → validar herramientas → inventariar → analizar → autorizar ensayo → reproducir → contrastar → informar**. No saltar condiciones de seguridad por una visita o vencimiento próximo.

## 0. Preparación, responsables y límites

El titular autoriza cambios, custodia respaldos, ingresa personalmente la clave BitLocker y trata con el servicio técnico. El agente local adquiere y analiza, registra comandos y explica cualquier cambio antes de solicitar permiso. Un revisor valida herramientas; un investigador puede consultar fuentes públicas sin acceso al expediente privado.

Preparar cargador original, disco externo privado, respaldo comprobado, espacio suficiente, registro visual sin secretos y recuperación BitLocker disponible **fuera de la evidencia**. El uso de un correo corporativo no demuestra que Windows esté administrado por dominio/MDM.

Durante adquisición: no actualizar BIOS/drivers/Windows, cambiar BCD, habilitar canales previamente desactivados, borrar logs, desactivar seguridad/BitLocker, alterar perfiles de energía, reparar Windows con SFC/DISM/CHKDSK, formatear ni ejecutar pruebas de carga. Una consulta en vivo deja huellas normales del sistema; no llamarla imagen forense inmutable.

## 1. Preservar el estado posterior al servicio

1. Si está encendida, capturar primero estado en vivo y registros; no reiniciar para entrar a BIOS antes.
2. Registrar fecha/hora local y UTC, diferencia frente a referencia externa, energía, batería, red, aplicaciones, versión Windows, núcleos/hilos visibles y mensajes sobre actualizaciones. No corregir el reloj ni fotografiar secretos.
3. Conservar privadamente correos originales y adjuntos, registros previos, XML/CPER, logs de ensayo e informe de servicio. Documentar remitente/destinatario, Message-ID, fechas y entregas/rebotes. Un correo del usuario que cita una parte no sustituye la orden de despacho del fabricante.
4. Fijar como instrumento histórico el commit `889e945f9fee1d6d6f57e938070280779c36460a`. Cada nueva revisión es un instrumento distinto; no actualizar silenciosamente durante una serie.
5. Preservar una copia íntegra de disco cuando sea viable y antes de cualquier reinstalación comparativa. EVTX no sustituye una copia de disco. Los hashes prueban integridad desde la captura, no autoría ni autenticidad histórica por sí solos.

**Entrega:** originales privados, bitácora, manifiesto SHA-256 y duplicado de custodia.

**P1:** no pruebas activas sin respaldo utilizable, recuperación disponible y registros previos/postservicio preservados. Evidencia perdida debe declararse, no reconstruirse como original.

## 2. Validar y ejecutar únicamente el recolector pasivo

Leer `VALIDACION.md`. Validar sintaxis con Windows PowerShell de 64 bits y probar funcionalmente en una máquina de ensayo antes de adquirir evidencia. No cambiar permanentemente la política de ejecución ni evadir controles de una organización.

Una vez autorizada y validada la herramienta, desde esta carpeta:

```powershell
.\RECOLECCION_V2.ps1 -OutputRoot 'E:\EvidenciaLenovo'
```

La carpeta destino debe existir. `-AllowSystemDrive` permite excepcionalmente captura en el volumen del sistema; documentarlo, sin equipararlo a respaldo externo. El recolector exporta EVTX antes de inventarios largos, deriva WHEA de System exportado y registra estados/códigos de retorno.

Revisar `ESTADOS.csv`, `RESUMEN.json`, hashes y apertura de EVTX. Distinguir `SIN_EVENTOS`, `AUSENTE`, `ERROR`, `TIMEOUT` y `CAMBIO_EN_VIVO`. Canal opcional ausente no demuestra manipulación. Fallo de exportación/lectura de System impide una conclusión negativa sobre WHEA.

**Entrega:** adquisición verificada y lista de fallos/ausencias. Nunca subir el directorio bruto.

**P2:** si faltan BCD, CPU, energía o System/WHEA, completar o declarar limitación; no certificar ausencia de restricciones.

## 3. Topología y funcionamiento de núcleos

Referencia de plataforma: Ryzen 7 7435HS, 8 núcleos y 16 hilos [T1].

1. Comparar CIM/WMI, Task Manager y BCD; registrar `numproc`, `onecpu` y otros parámetros sin borrarlos.
2. Tras preservar el estado, consultar BIOS sin guardar cambios. Registrar núcleos/SMT/energía solo si están expuestos; no desbloquear menús.
3. Construir mapa `grupo Windows → índice lógico → núcleo → hermano SMT → APIC` mediante topología del SO y CPUID validado cuando corresponda [T2,T3]. No usar APIC/2 universalmente ni equiparar APIC 14 a índice lógico Windows 14.
4. Registrar CPU Sets, parking y afinidad. Aparcamiento temporal no equivale a eliminación del núcleo.
5. Solo después de adquirir evidencia y con autorización de carga ligera, comprobar retorno de afinidad, CPU donde ejecuta cada hilo y progreso individual. Un contador agregado no basta.

**Entrega:** tabla de capacidad/topología y limitaciones.

**P3:** preservar cualquier núcleo ausente antes de habilitarlo. Sin mapeo validado, reportar por APIC sin atribuir núcleo exacto. 8C/16T enumerados no descartan restricciones energéticas ni demuestran cobertura de prueba.

## 4. Imagen, energía y mantenimiento

Crear matriz: **observación / evidencia / valor previo / cambio comprobado / autor conocido o desconocido / efecto posible**.

- Capturar plan completo: mínimo/máximo, boost, EPP, parking, frecuencia máxima, AC/DC, suspensión y reposo; además modo Windows y perfil Lenovo. Un overlay puede modificar el resultado efectivo.
- El mínimo del 80 % del reporte histórico incluía experimentos del usuario: no atribuirlo al técnico sin cronología.
- Registrar firmware, paquetes y controladores efectivamente vinculados a dispositivos. `pnputil /enum-drivers` no es inventario de todos los drivers efectivos.
- Revisar WU/GPO/MDM, restricciones de dispositivos, pausas, servicios y tareas. `ExcludeWUDriversInQualityUpdate` no apaga todas las actualizaciones [T4]. Un servicio detenido en una instantánea no prueba desactivación permanente.
- Preservar edición/build, software OEM y logs SetupAPI/Panther/Sysprep. No deducir autenticidad u origen de una imagen por apariencia. Solicitar medio, versión, hash y cambios aplicados.
- Investigar canal Insider/configuración anterior como variable, sin asumirlo a partir de una cadena del informe ni usarlo como refutación automática de WHEA.
- DMI/seriales pueden ser genéricos o reprogramados. Corroborar sustitución física con FRU, parte de servicio y evidencia disponible; un serial aislado no basta.

**Entrega:** matriz y pendientes de atribución.

**P4:** no corregir políticas ni reactivar actualizaciones masivas antes de registrar; cambiarían múltiples variables y podrían incluir firmware.

## 5. Revalidar WHEA desde originales

1. Decodificar EVTX/XML/RawData, no solo Markdown o imágenes.
2. Validar CPER, longitudes, revisiones, descriptores y tipos de todas las secciones; no sobrescribir una sección con otra [T5].
3. Separar CPU/SMCA, PCIe, memoria y otros; extraer APIC, banco, STATUS, IPID, códigos y severidad solo cuando sean válidos.
4. LS_V2 identifica la unidad reportante load/store, no por sí solo una celda SRAM L1 dañada. Corroborar códigos y patrón; no excluir toda interacción de memoria solo porque la RAM de sistema no sea ECC.
5. WHEA también contempla errores no corregidos [T6]. Kernel-Power 41 no identifica por sí solo CPU o voltaje. Un 0xC000001D aislado tampoco es prueba autónoma de corrupción física.
6. Los 101 registros históricos incluyen 70 espontáneos y 31 de la prueba: no duplicar. Las asociaciones y valores p no son probabilidades de avería.

**Entrega:** tabla trazable de registros y alternativas: CPU, regulación/placa, firmware/microcódigo, gestión energética/controladores u otras compatibles.

**P5:** sin originales, el informe histórico permanece como evidencia secundaria pendiente de corroboración.

## 6. Prueba activa: puerta actualmente cerrada

La v1.0.1 no cumple esta fase. Corregir y superar los casos del informe de código. La escritura/activación/restauración no es atómica: no prometer riesgo cero ni recuperación tras un cuelgue sin haberla validado [T7].

Precondiciones: consentimiento específico, respaldo, recuperación BitLocker, cargador estable, sin trabajo no guardado ni actualizaciones por ejecutar, logs legibles, afinidad verificada, destino durable y temperatura observable de forma fiable. No instalar telemetría no auditada para completar un requisito.

| Fase | Máximo planificado | Acción |
|---|---:|---|
| A0 | 10 min | Estado entregado, carga ligera validada y telemetría |
| B | 15 min | Únicamente la intervención de rendimiento autorizada |
| A1 | 10 min | Restauración verificada y recuperación |

No modificar directamente voltaje, BIOS, SMT, RAM ni drivers. Las duraciones no garantizan sensibilidad. Medir rendimiento efectivo por CPU durante toda B; un porcentaje Windows no es un voltímetro [T8]. Sin tensión fiable, describir el ensayo como estado energético/bajo rendimiento, no como Vmin eléctrico medido.

**Detener inmediatamente el estímulo** al primer WHEA, mismatch, cuelgue, pérdida de AC/logs/telemetría/afinidad, cambio inesperado de perfil o temperatura ≥85 °C. Ese umbral es conservador del protocolo, no especificación del fabricante; usar el menor si el OEM exige menos. Sin lectura térmica fiable, no realizar B.

Sin cuelgue: restaurar y verificar antes de A1. Con cuelgue: recuperar y preservar, no repetir para acumular errores. Registrar Run-ID, UTC/offset, tiempo monotónico, RecordID, AC, batería, perfiles y progreso individual. Eventos retardados o en fronteras temporales quedan ambiguos, no adjudicados automáticamente.

Clasificación obligatoria:

- `FALLO_REPRODUCIDO_MISMA_FIRMA`: registro nuevo validado concordante. Afirmar dependencia exclusiva de B exige además A0/A1 válidos.
- `OTRO_ERROR`: distinto origen, sin atribuirlo al núcleo histórico.
- `CUELGUE_ASOCIADO`: requiere análisis causal; no demuestra Vmin por sí mismo.
- `SIN_REPRODUCCION_EN_ESTA_CORRIDA`: todas las fases/cobertura/estímulo/lectura/restauración válidos, cero errores. No significa placa sana.
- `INCONCLUSO/ABORTADO`: fase ausente, duración insuficiente, estímulo o restauración no comprobados, lectura fallida u otra limitación.

**P6:** mantener bloqueada cualquier corrida hasta aprobación de herramienta y precondiciones. Una positiva no se repite para acumular eventos.

## 7. Escenarios cotidianos, por separado

Tras P6 y autorización específica:

1. Una transición corriente→batería sin alterar simultáneamente ahorro, drivers o BIOS.
2. Identificar umbral actual e histórico del ahorro; no asumir 30 %. No descargar por debajo del 20 % para forzarlo; si queda fuera del rango, omitir y documentar.
3. Dos ciclos de suspensión/reanudación usando estados admitidos por `powercfg /a`. No forzar S3 por registro en Modern Standby.
4. Dos reinicios de control y dos encendidos tras apagados completos de al menos 60 minutos. Documentar Fast Startup y método; hibernación/reinicio no equivale a frío.

Cada escenario recibe identificador y manifiesto. Primer fallo: preservar y detener. Carga máxima no sustituye reposo y transiciones energéticas.

## 8. Comparación discriminante opcional

Conservar la instalación entregada; preferir unidad/copia de ensayo autorizada, Windows soportado, medio oficial y drivers identificados. No sobrescribir el original ni extraer hardware sin autorización apropiada.

Mantener firmware y condiciones fijas. Una instalación distinta cambia muchas variables: aislar después una diferencia por vez en la copia. No actualizar todo ni degradar BIOS por ensayo. OEM estable y otra imagen inestable indican dependencia de configuración, no automáticamente malicia o ausencia de arreglo legítimo. Ausencia de errores en Linux no demuestra exposición al mismo estado de Windows.

**Entrega:** A/B controlado o lista explícita de confusores.

## 9. Informe y aceptación

Separar **hechos corroborados / inferencias / alternativas / pendientes**. Los antecedentes reputacionales no sustituyen evidencia técnica.

Solicitar al CAS/fabricante partes autorizadas/despachadas/devueltas, FRU/condición, justificación de no sustitución, medio Windows, cambios de energía/BCD/driver, alcance/duración/ruta de mantenimiento de restricciones y pruebas que corroboran o refutan la firma histórica. Cobertura y plazos deben confirmarse en expediente privado; no publicar identificadores ni enviar comunicaciones automáticamente.

No basta con encender o mostrar cero eventos tras formateo. La conformidad requiere capacidad sin reducción injustificada, estabilidad en escenarios pertinentes y explicación de las restricciones. Ningún muestreo finito garantiza ausencia absoluta de fallas futuras.

## Referencias técnicas

- T1 AMD 7435HS: https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-7000-series/amd-ryzen-7-7435hs.html
- T2 Topología: https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getlogicalprocessorinformationex
- T3 CPU Sets: https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-system_cpu_set_information
- T4 Windows Update: https://learn.microsoft.com/en-us/windows/deployment/update/waas-configure-wufb
- T5 CPER/WHEA: https://learn.microsoft.com/en-us/windows-hardware/drivers/whea/error-records
- T6 Errores corregidos/no corregidos: https://learn.microsoft.com/en-us/windows-hardware/drivers/whea/error-processing
- T7 Escritura de energía: https://learn.microsoft.com/en-us/windows/win32/api/powersetting/nf-powersetting-powerwriteacvalueindex
- T8 Rendimiento: https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-minperformance
