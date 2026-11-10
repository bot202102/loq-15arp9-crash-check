# Validación y límites

## Qué cubre esta publicación

Revisión estática de instrumentos/documentos y ocho escenarios Python sintéticos de ramas del clasificador v1.0.1. No se ejecutó PowerShell en la laptop ni se comprobó el comportamiento real del recolector en Windows. No se implementó una versión activa corregida.

La edición pública se deriva del paquete privado v2 con datos privados omitidos y documentación de continuidad adaptada al repositorio. No reutilizar los hashes del ZIP privado para verificar estos archivos.

## Reproducir casos lógicos

Desde la raíz:

```sh
python audit/v2/validar_logica.py
```

Produce `audit/v2/PRUEBAS_LOGICAS.json`. Los asserts comprueban una transcripción de condiciones de clasificación, no PowerShell, CPER, el recolector, la recuperación ni el hardware.

## Sintaxis Windows obligatoria, sin ejecutar el recolector

Desde `audit/v2`, con Windows PowerShell de 64 bits en una máquina de ensayo:

```powershell
$tokens = $null
$parseErrors = $null
$path = (Resolve-Path '.\RECOLECCION_V2.ps1').Path
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    $path, [ref]$tokens, [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    $parseErrors | Format-List *
    throw 'No ejecutar: hay errores de sintaxis.'
}
'Sintaxis aceptada por este motor. Falta validacion funcional.'
```

Un parse correcto no valida datos, permisos, canales, errores, ni efectos laterales. No ejecutar en evidencia únicamente porque la sintaxis pasó.

## Ensayo funcional pendiente

1. Comprobar destino privado externo y directorio nuevo, sin sobrescritura ni cambios de configuración consultada.
2. Probar canal ausente, fallo wevtutil, falta de permisos y cero eventos; comprobar estados distintos y reapertura de System exportado.
3. Verificar que no inicia actualizaciones, instala drivers ni ejecuta carga. Registrar las huellas normales que produzcan consultas/Windows.
4. Verificar manifiesto, hash externo y cierre; no modificar archivos después de calcular sus hashes.
5. Revisar datos personales/secretos antes de compartir una copia. No publicar dumps ni claves.
6. Si falla, conservar salida, corregir en copia con nueva versión/hash y repetir. Nunca presentar adquisición parcial como completa.

## Autorizaciones separadas

Validar sintaxis no autoriza adquisición. Adquirir no autoriza modificar Windows. Corregir el test no autoriza inducir fallos. Publicar esta rama no autoriza merge ni comunicaciones externas. Seguir las puertas del plan.
