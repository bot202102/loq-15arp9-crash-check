# Revisión de cuelgues del LOQ 15ARP9: núcleo de CPU débil a bajo voltaje

*English version: [README.md](README.md)*

¿Tu **Lenovo LOQ 15ARP9** (u otra laptop con procesador Ryzen serie 7035) hace algo de esto?

- se cuelga o reinicia **en suspensión o Modern Standby**;
- falla el **primer encendido después de horas apagada** (Reparación automática, pantalla negra), pero en el segundo intento arranca bien;
- se cuelga **poco después de desconectar el cargador**, o cuando **el ahorro de batería se activa al 30 %**;
- muestra en el Visor de eventos **"Error de hardware corregido — Componente: Memoria" (WHEA-Logger 47)**, aunque las pruebas de memoria salen bien.

En nuestro equipo todo eso venía de **un núcleo del procesador cuya caché L1 de datos falla a bajo voltaje**: un defecto de hardware. Windows lo rotula, por error, como un problema de RAM. Pudimos encender y apagar los errores a voluntad; esa es la prueba que incluye este repositorio.

**Necesitamos tus datos** para saber si es un problema de lote o de diseño, o solo unos pocos equipos fallados. Toma 1 minuto (revisión de solo lectura) o unos 23 minutos (prueba activa opcional).

---

## 1. Revisión de solo lectura (1 minuto, no cambia nada)

1. Descarga este repositorio (**Code → Download ZIP**) y descomprímelo.
2. Haz doble clic en **`RUN-CHECK.cmd`**. No pide permisos de administrador.
3. Aparece un archivo `loq-report-xxxxxxxx.md`. **[Abre un issue](../../issues/new/choose)** y pega su contenido.

Qué busca:

| Código | Señal | Qué significa |
|---|---|---|
| **S1** | Errores WHEA 47, decodificados desde el registro de *machine check*, con ≥80 % en **un solo núcleo físico** y reportados por una unidad del núcleo (LS / IF / L2 …) | Un núcleo del procesador está dañado. **Puede ser cualquier núcleo**: el reporte te dice cuál |
| **S2** | Windows dice "Memoria", pero tu RAM no tiene ECC y la unidad que lo reporta no es el controlador de memoria | **No** es tu RAM. Cambiarla no servirá |
| **S3** | El primer arranque después de un apagado ordenado falla mucho más tras >60 min apagada que tras <10 min | Falla al encender en frío |
| **S4** | Los cuelgues se concentran con batería, en relación con el tiempo que pasa con batería | Punto de operación de bajo voltaje con batería |
| **S5** | La mayoría de los cuelgues ocurren en Modern Standby | Reposo profundo a bajo voltaje |
| **S6** | Aplicaciones que se cierran con `0xC000001D` (instrucción ilegal) dentro de DLL del sistema | El procesador leyó instrucciones corruptas |

También muestra el **estado mínimo del procesador** de tu plan de energía. Si dice algo como `AC 80 % / DC 5 %`, eso explica por qué la laptop puede ser estable enchufada y colgarse con batería.

## 2. Prueba activa opcional (unos 23 minutos, puede colgar el equipo)

`RUN-VMIN-TEST.cmd` corre tres fases con el cargador conectado:

| Fase | Duración | Estado del procesador | Lo esperable en un equipo afectado |
|---|---|---|---|
| A0 | 3 min | tu configuración normal | 0 errores |
| B | hasta 15 min | **estado de rendimiento mínimo = voltaje mínimo** | errores WHEA 47 de un núcleo (en el nuestro, a los ~5 min) |
| A1 | 5 min | configuración normal otra vez | los errores se detienen |

Corre una carga liviana en **todos** los procesadores lógicos, así que aparece el núcleo débil, sea cual sea. El script decodifica cada error nuevo a medida que llega y genera `vmin-report-….md`.

**Antes de correrla:** guarda tu trabajo, cierra todo, deja el cargador conectado y **no cierres la tapa**. Si tu disco usa BitLocker, ten a mano la clave de recuperación (en tu celular o en https://aka.ms/myrecoverykey): varios cuelgues seguidos pueden hacer que Windows la pida.

**Si se cuelga:** deja que reinicie, inicia sesión y ejecuta `loq-vmin-test.ps1 -Report`. Lee la corrida interrumpida y genera el reporte. Que se cuelgue en la fase B también es un resultado.

Para revisar primero el mecanismo, sin bajar el voltaje: `loq-vmin-test.ps1 -Rehearsal` (3 × 1 min con un tope inofensivo de 90 %).

### Por qué tu PC no queda en un bucle de cuelgues

El diseño obvio (guardar el valor bajo y restaurarlo después del reinicio) no es seguro. El servicio de energía de Windows aplica el plan guardado muy temprano en el arranque, **antes** de que pueda correr cualquier tarea de restauración o script de inicio de sesión. Por eso esta prueba nunca deja guardado el valor bajo:

1. escribe los valores de prueba y los activa;
2. **de inmediato** vuelve a escribir tus valores originales en el registro, *sin* activarlos. Microsoft documenta que los cambios al plan activo "no tienen efecto hasta llamar a PowerSetActiveScheme";
3. antes de seguir verifica dos cosas: que el registro tiene tus valores y que el tope de verdad está activo.

El procesador conserva el tope en memoria mientras el registro ya tiene tus valores normales. Si el equipo se cuelga, el tope desaparece y Windows arranca con tu configuración normal desde el primer instante. Los valores de prueba quedan en el registro unos 0,1–0,2 s (queda anotado en el reporte). El script se niega a correr con batería, termina la fase B al tercer error y se detiene si desconectas el cargador.

## 3. Envía tu retroalimentación (por favor, aunque no encuentre nada)

**[Abre un issue](../../issues/new/choose)** con tus reportes. Cuéntanos:

- tu modelo, versión de BIOS y antigüedad del equipo;
- qué síntomas tienes (o "ninguno", que también sirve);
- si corriste la prueba activa: si aparecieron errores, a los cuántos minutos, en qué núcleo y si se colgó;
- cualquier cosa que no se entendiera o no funcionara. Si el script falló, pega lo que mostró la consola.

**Un resultado negativo vale tanto como uno positivo.** Solo muchos reportes permiten distinguir un problema de diseño de unos pocos equipos fallados.

## Caso de referencia (#1)

LOQ 15ARP9 · 83JC · Ryzen 7 7435HS · BIOS PQCN31WW (la última disponible) · 2 × 8 GB Samsung DDR5 (sin ECC). Los problemas empezaron unos 10 meses después de la compra y empeoraron cada semana.

- **Revisión de solo lectura: 6 de 6 señales.** 101 errores WHEA, todos de **LS_V2 (caché L1 de datos) del núcleo físico 7** (APIC 14/15). Fallaron 8 de 9 encendidos en frío contra 0 de 11 en tibio (p = 7×10⁻⁵). 9 de 18 cuelgues ocurrieron con batería, en el 8 % del tiempo (p = 4×10⁻⁶). [Reporte completo](examples/loq-report-21fdaea9.md). De esos 101 registros, 31 salieron de la prueba activa de abajo. El mínimo `DC 80 %` de ese reporte era un experimento temporal.
- **Prueba activa** (corrida con la versión anterior de este script, mismo mecanismo en memoria):

  | Fase | Duración | WHEA 47 | Núcleo |
  |---|---|---|---|
  | Normal (enchufada, mínimo AC 80 %) | 156 h | **0** | — |
  | **Voltaje mínimo** | 15,7 min | **31** (el primero a los 5,5 min) | **31/31 en APIC 14 = núcleo 7** |
  | Normal otra vez | 7,8 min | **0** | — |

- **Corridas con batería:** dos corridas desde 79,5 % se colgaron **56 y 74 s después de que la batería bajó del 30 %**, el momento en que el ahorro de energía de Windows baja el rendimiento del procesador. Un cuelgue dejó un volcado `0x20001 HYPERVISOR_ERROR`; 85 s antes, una aplicación se cerró con `0xC000001D` dentro de `ntdll.dll`.
- Subir a 80 % el mínimo del procesador con batería hizo que la laptop aguantara más (de 56 a 91 min), pero no evitó los cuelgues.

## Reportes públicos del mismo modelo (aún sin decodificar)

- r/LenovoLOQ — [*LOQ 15ARP9 boot loops / Automatic Repair, but works perfectly once it boots*](https://www.reddit.com/r/LenovoLOQ/comments/1wvyrv0/loq_15arp9_boot_loops_automatic_repair_but_works/): fallas al encender en frío, reinicios ocasionales con batería, Kernel-Power 41 con bugcheck 0 y sin volcado, con PQCN31WW.
- r/LenovoLOQ — [*LOQ 15ARP9 suddenly restarts/crashes immediately when unplugged from AC*](https://www.reddit.com/r/LenovoLOQ/comments/1vlhd20/loq_15arp9_suddenly_restartscrashes_immediately/): se reinicia al desconectar el cargador, y una vez al cambiar Lenovo Vantage de Rendimiento a Silencioso. Es otra bajada a un estado de menor energía.
- r/Lenovo — [*Lenovo LOQ 15ARP9 nightmare*](https://www.reddit.com/r/Lenovo/comments/1up5odx/lenovo_loq_15arp9_nightmare/): se congela en reposo y en suspensión. El autor dice que dos cambios de placa no ayudaron y que una actualización de BIOS de julio arregló los congelamientos en suspensión. **Esto puede contradecir nuestra hipótesis, o mostrar que el firmware puede ocultarla.** En nuestro equipo, la última BIOS no ayudó.

Si eres uno de ellos: los datos decodificados son lo que nadie ha publicado todavía.

## Preguntas frecuentes

**¿Siempre es el núcleo 7?** No. El núcleo 7 es el de *nuestro* equipo. Las herramientas reportan el núcleo que genere los errores, y pueden ser varios. Si muchos equipos mostraran el mismo núcleo, eso ya sería un hallazgo importante.

**La revisión muestra 0 errores WHEA, pero igual se me cuelga.** WHEA solo registra los errores que el procesador logró *corregir*. Un error no corregido cuelga el equipo antes de que se registre nada. Corre la prueba activa.

**¿La prueba puede dañar mi procesador?** No hace overclock ni sube voltajes. Mantiene el procesador en su propio estado normal de rendimiento mínimo, el mismo que usa con batería y en reposo. El riesgo es un cuelgue, es decir, perder lo que no hayas guardado.

**¿Se arregla actualizando la BIOS?** En nuestro equipo, actualizar a la última BIOS (PQCN31WW) no cambió nada.

**¿Funciona en Intel u otras marcas?** Las revisiones corren en cualquier laptop con Windows, pero decodificar *qué núcleo* falló solo está implementado para AMD (SMCA).

**¿Cambiar la RAM o la batería lo arregla?** No, si tienes S1 + S2: los errores vienen de un núcleo del procesador. En estas laptops el procesador va soldado, así que la reparación en garantía es cambiar la placa madre.

**¿Puedo hacer algo mientras tanto?** En nuestras pruebas, con un mínimo de procesador más alto los cuelgues con batería tardaban más, pero no desaparecían. Para trabajo importante, mantenla enchufada y respalda tus datos.

## Privacidad

Los reportes contienen modelo, BIOS, procesador, versión de Windows, números de parte de la RAM y estadísticas. **No incluyen número de serie, nombre de usuario ni rutas de archivos.** El identificador del equipo son los primeros 8 caracteres hexadecimales de SHA-256(número de serie + `MachineGuid` aleatorio del equipo). Se mantiene igual entre corridas, así que se detectan duplicados, pero no permite recuperar tu número de serie. Lee ambos scripts antes de correrlos: son PowerShell simple.

## Límites

- La revisión lee el registro de eventos de Windows, que suele abarcar solo las últimas 4–8 semanas.
- La reconstrucción del estado de energía (cargador / batería / suspensión al momento del cuelgue) es aproximada.
- Un reporte es un solo dato.

Licencia MIT · Sin garantía · Sin relación con Lenovo ni AMD.
