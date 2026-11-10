# Antecedentes públicos — alcance y límites

**Edición pública del informe de investigación previo, fechado 10-11-2026.** La investigación previa fue directa; no se ejecutó un subagente. Esta publicación no es una nueva verificación independiente de cada enlace. Las pistas no corroboradas se mantienen como tales.

## Conclusión de la revisión previa

Se identificaron antecedentes de software preinstalado problemático y una función de firmware insegura, y relatos de usuarios sobre mitigaciones energéticas. **No se identificó una resolución, política oficial o informe técnico verificable que pruebe una práctica de Lenovo consistente en desactivar deliberadamente núcleos dañados en garantía para evitar sustituir placas.** No encontrar esa prueba tampoco demuestra que nunca haya ocurrido. La configuración de un equipo y la intención del técnico requieren evidencia propia.

## 1. Superfish / VisualDiscovery

La FTC anunció un acuerdo en septiembre de 2017 sobre software preinstalado que comprometía la seguridad de determinadas laptops. La aprobación final del acuerdo se documentó el 02-01-2018; incluyó obligaciones de consentimiento y un programa de seguridad auditado durante veinte años [R1,R2]. Lenovo discrepó de las alegaciones y comunicó que había dejado de precargar el programa en 2015 [R3].

**Pertinencia:** transparencia del software instalado. **Límite:** no demuestra ocultación de daños físicos ni vínculo con LOQ 15ARP9 o una intervención actual. No convertir el acuerdo en una admisión general de fraude en garantías.

## 2. Lenovo Service Engine

El comunicado Lenovo del 11-08-2015 describió vulnerabilidades de una función BIOS en determinados equipos de consumo y medidas para retirarla/desactivarla [R4].

**Pertinencia:** revisar también firmware y software OEM. **Límite:** no demuestra presencia de LSE en esta plataforma, recorte de núcleos ni intención del servicio técnico. No aplicar utilidades antiguas al equipo investigado.

## 3. Relatos LOQ: pistas, no hechos acreditados

La revisión previa localizó un hilo LOQ 15ARP9 cuyos extractos describían elevar el mínimo del procesador con batería al 80 %, reducir procesadores en msconfig y cambios de arranque como mitigaciones [R5]. No se verificaron identidad, originales, logs ni atribución de esos cambios al fabricante. Las fechas exactas de publicaciones/comentarios deben corroborarse en la fuente antes de usarlas como evidencia pública independiente.

Otro relato titulado “Faulty unit, 3 technician visits, and Lenovo says only refund — no replacement” fue accesible solo mediante un extracto indexado; no se corroboró la página completa ni su fecha exacta [R6]. No se usa para atribuir malicia.

Estas pistas sirven para definir comprobaciones de BCD, topología, energía y arranque. No convertir publicaciones cruzadas de un mismo autor en casos independientes.

## 4. Explicaciones alternativas

Microsoft documenta ExcludeWUDriversInQualityUpdate [R7]. Excluir drivers no equivale a apagar todo Windows Update; puede responder a compatibilidad, pero debe quedar documentado alcance, versión afectada, duración y mantenimiento.

Una imagen estable puede corregir una interacción legítima, evitar el desencadenante o simplemente no haberse observado lo suficiente. La comparación controlada discrimina efectos; la intención exige evidencia adicional. Un antecedente reputacional no sustituye ese análisis.

## Fuentes para corroboración

- R1 FTC, 05-09-2017: https://www.ftc.gov/news-events/news/press-releases/2017/09/lenovo-settles-ftc-charges-it-harmed-consumers-preinstalled-software-its-laptops-compromised-online
- R2 FTC, expediente 152-3134: https://www.ftc.gov/legal-library/browse/cases-proceedings/152-3134-lenovo-inc
- R3 Postura Lenovo, 05-09-2017: https://news.lenovo.com/pressroom/press-releases/lenovo-statement-on-federal-trade-commission-ftc-settlement/
- R4 Lenovo Service Engine, 11-08-2015: https://news.lenovo.com/pressroom/press-releases/lenovo-statement-on-lenovo-service-engine-lse-bios/
- R5 Relato LOQ: https://www.reddit.com/r/LenovoLOQ/comments/1uz6eev/lenovo_loq_15arp9_intermittent_cold_boot_freezes/
- R6 Relato de servicio: https://www.reddit.com/r/LenovoLOQ/comments/1ro08ph/faulty_unit_3_technician_visits_and_lenovo_says/
- R7 Microsoft: https://learn.microsoft.com/en-us/windows/deployment/update/waas-configure-wufb

## Encargo para investigador independiente/subagente

Buscar evidencia pública de reparaciones Lenovo con reducción de núcleos/SMT, afinidad, recorte de frecuencia, mínimos altos o bloqueo de drivers en vez de reemplazo de hardware. Priorizar LOQ 15ARP9/7435HS; distinguir fabricante, CAS, terceros y ajustes hechos por usuarios. Por resultado: fecha del hecho/publicación, URL, fuente primaria, hecho acreditado, alegación y evidencia faltante. Buscar también correcciones legítimas y resultados contradictorios. Corroborar textos completos y evitar duplicados. No generalizar desde Superfish/LSE. No usar datos privados, acceder a la laptop, instalar software, contactar terceros ni modificar el repositorio. No afirmar ejecución de un subagente cuando no existe esa capacidad.
