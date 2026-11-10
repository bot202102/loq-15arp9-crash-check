#requires -Version 5.1
<#
Adquisicion LOGICA EN VIVO v2.0. No ejecuta pruebas de carga ni modifica deliberadamente
BCD, firmware, servicios, drivers o politicas. Escribe archivos de evidencia nuevos.
NO es una imagen forense de disco ni una operacion sin huella: Windows, antivirus,
PowerShell y las utilidades consultadas pueden generar eventos/archivos transitorios.
Usar Windows PowerShell de 64 bits elevado. Preferir un disco externo privado.
No recopila contrasenas, claves BitLocker ni claves de producto. Las salidas SI pueden
contener identificadores, nombres de cuenta y rutas: NO publicar en GitHub.
Validacion funcional en Windows pendiente. Ver VALIDACION.md y el plan.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [switch]$AllowSystemDrive,
    [ValidateRange(10,300)][int]$CommandTimeoutSeconds = 90
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Este recolector requiere Windows.' }
if (-not [Environment]::Is64BitProcess) { throw 'Abra Windows PowerShell de 64 bits.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Se requiere una consola elevada para que la adquisicion no omita registros por permisos.'
}
if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
    throw 'OutputRoot debe ser una carpeta ya existente, preferiblemente en disco externo.'
}
$root = (Resolve-Path -LiteralPath $OutputRoot).ProviderPath
if (-not $AllowSystemDrive -and [IO.Path]::GetPathRoot($root).TrimEnd('\') -eq $env:SystemDrive) {
    throw 'La salida esta en el volumen del sistema. Use disco externo o autorice -AllowSystemDrive y documente la limitacion.'
}
$start = Get-Date
$runId = 'lenovo-{0}-{1}' -f $start.ToString('yyyyMMdd-HHmmss'), ([Guid]::NewGuid().ToString('N').Substring(0,8))
$out = Join-Path $root $runId
New-Item -ItemType Directory -Path $out -ErrorAction Stop | Out-Null
$script:ledger = New-Object 'System.Collections.Generic.List[object]'
$utf8 = New-Object Text.UTF8Encoding($true)
function Write-Text([string]$Path,[string]$Text) {
    [IO.File]::WriteAllText($Path,$Text,$utf8)
}
function Add-Status([string]$Name,[string]$State,[string]$Detail,[bool]$Required=$false) {
    $script:ledger.Add([pscustomobject]@{
        utc=[DateTime]::UtcNow.ToString('o'); step=$Name; state=$State;
        required=$Required; detail=$Detail
    }) | Out-Null
}
function Save-Read([string]$Name,[scriptblock]$Action,[bool]$Required=$false) {
    try {
        $result = & $Action
        Write-Text (Join-Path $out ($Name+'.txt')) (($result | Out-String -Width 4096))
        Add-Status $Name 'OK' 'Consulta completada; revisar alcance y contenido.' $Required
    } catch {
        Write-Text (Join-Path $out ($Name+'.error.txt')) ($_ | Out-String)
        Add-Status $Name 'ERROR' $_.Exception.Message $Required
    }
}
# Argumentos construidos por el script: no se aceptan comandos libres del usuario.
function Invoke-ReadCommand([string]$Name,[string]$Exe,[string]$Arguments,[bool]$Required=$false) {
    $proc = New-Object Diagnostics.Process
    try {
        $proc.StartInfo.FileName = Join-Path $env:SystemRoot ('System32\'+$Exe)
        $proc.StartInfo.Arguments = $Arguments
        $proc.StartInfo.UseShellExecute = $false
        $proc.StartInfo.CreateNoWindow = $true
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.RedirectStandardError = $true
        if (-not $proc.Start()) { throw 'No se inicio el proceso de consulta.' }
        $stdout = $proc.StandardOutput.ReadToEndAsync()
        $stderr = $proc.StandardError.ReadToEndAsync()
        $timedOut = -not $proc.WaitForExit($CommandTimeoutSeconds * 1000)
        if ($timedOut) { $proc.Kill(); $proc.WaitForExit() }
        Write-Text (Join-Path $out ($Name+'.stdout.txt')) ($stdout.GetAwaiter().GetResult())
        Write-Text (Join-Path $out ($Name+'.stderr.txt')) ($stderr.GetAwaiter().GetResult())
        $code = $proc.ExitCode
        Write-Text (Join-Path $out ($Name+'.command.txt')) ("$Exe $Arguments`r`nExitCode=$code`r`nTimeout=$timedOut")
        if ($timedOut) { Add-Status $Name 'TIMEOUT' 'Proceso de consulta detenido por tiempo limite.' $Required; return $false }
        if ($code -ne 0) { Add-Status $Name 'ERROR' "ExitCode=$code; ver stderr y stdout." $Required; return $false }
        Add-Status $Name 'OK' "ExitCode=$code" $Required
        return $true
    } catch {
        Write-Text (Join-Path $out ($Name+'.error.txt')) ($_ | Out-String)
        Add-Status $Name 'ERROR' $_.Exception.Message $Required
        return $false
    } finally { $proc.Dispose() }
}
function Read-RegTree([string]$Name,[string]$Key) {
    if (Test-Path -LiteralPath ('Registry::'+$Key)) {
        $null = Invoke-ReadCommand $Name 'reg.exe' ('query "'+$Key+'" /s')
    } else {
        Write-Text (Join-Path $out ($Name+'.txt')) ('AUSENTE: '+$Key)
        Add-Status $Name 'AUSENTE' $Key
    }
}
function Copy-LiveFile([string]$Source,[string]$DestName) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { Add-Status $DestName 'AUSENTE' $Source; return }
    try {
        $item = Get-Item -LiteralPath $Source
        $before = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
        $dest = Join-Path $out $DestName
        Copy-Item -LiteralPath $Source -Destination $dest -ErrorAction Stop
        $copyHash = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
        $after = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
        $meta = [ordered]@{source=$Source;length=$item.Length;last_write_utc=$item.LastWriteTimeUtc.ToString('o');source_hash_before=$before;copy_hash=$copyHash;source_hash_after=$after}
        Write-Text ($dest+'.metadata.json') ($meta | ConvertTo-Json -Depth 5)
        if ($before -eq $copyHash -and $after -eq $copyHash) { Add-Status $DestName 'OK' 'Copia y hashes fuente/copia coinciden.' }
        else { Add-Status $DestName 'CAMBIO_EN_VIVO' 'El archivo cambio durante la copia; no atribuirlo automaticamente a manipulacion.' }
    } catch { Add-Status $DestName 'ERROR' $_.Exception.Message }
}
Write-Text (Join-Path $out '00-ADVERTENCIA.txt') @'
Adquisicion logica en vivo, no imagen de disco. No se prueba estabilidad del hardware.
Un archivo vacio NO significa ausencia de problemas. Revisar ESTADOS.csv y RESUMEN.json.
Los hashes preservan integridad desde la captura; NO acreditan por si solos autenticidad,
autor de un cambio ni fecha historica. No publicar este directorio sin anonimizar una copia.
No se recopilan claves de recuperacion. Mantenerlas fuera de este paquete.
'@
if ($PSCommandPath) { Copy-LiveFile $PSCommandPath '00-recolector-ejecutado.ps1' }
Save-Read '01-tiempo-contexto' {
    Get-Date -Format o
    [DateTime]::UtcNow.ToString('o')
    Get-TimeZone | Format-List *
    $PSVersionTable | Out-String
    'ExternalRoot='+$root
    'SystemDriveOverride='+$AllowSystemDrive.IsPresent
    'Nota: la hora del equipo no constituye una fuente temporal independiente.'
} $true
# Prioridad: exportar registros originales ANTES de inventarios mas largos.
$channels = @(
    'System','Application','Setup',
    'Microsoft-Windows-WindowsUpdateClient/Operational',
    'Microsoft-Windows-Kernel-WHEA/Errors',
    'Microsoft-Windows-DeviceSetupManager/Admin',
    'Microsoft-Windows-GroupPolicy/Operational',
    'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin'
)
foreach ($channel in $channels) {
    $tag = '02-'+($channel -replace '[^a-zA-Z0-9_-]','_')
    $required = $channel -eq 'System'
    $null = Invoke-ReadCommand ($tag+'-metadata') 'wevtutil.exe' ('gl "'+$channel+'"') $required
    $null = Invoke-ReadCommand ($tag+'-info') 'wevtutil.exe' ('gli "'+$channel+'"') $required
    $target = Join-Path $out ($tag+'.evtx')
    $ok = Invoke-ReadCommand ($tag+'-export') 'wevtutil.exe' ('epl "'+$channel+'" "'+$target+'"') $required
    if ($ok) {
        if (-not (Test-Path -LiteralPath $target) -or (Get-Item -LiteralPath $target).Length -eq 0) {
            Add-Status ($tag+'-archivo') 'ERROR' 'El comando termino sin archivo EVTX utilizable.' $required
        } else {
            try {
                $null = Get-WinEvent -Path $target -MaxEvents 1 -ErrorAction Stop
                Add-Status ($tag+'-lectura') 'OK' 'EVTX reabierto; comprobacion parcial de lectura.' $required
            } catch {
                if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { Add-Status ($tag+'-lectura') 'SIN_EVENTOS' 'EVTX legible sin eventos; revisar si canal habilitado.' $required }
                else { Add-Status ($tag+'-lectura') 'ERROR' $_.Exception.Message $required }
            }
        }
    }
}
# Derivar WHEA del EVTX exportado, no de una segunda ventana temporal del log vivo.
try {
    $systemCopy = Join-Path $out '02-System.evtx'
    $events = @(Get-WinEvent -Path $systemCopy -FilterXPath "*[System[Provider[@Name='Microsoft-Windows-WHEA-Logger']]]" -ErrorAction Stop)
    Write-Text (Join-Path $out '03-WHEA-raw.xml') ("<Events>`r`n" + (($events | ForEach-Object { $_.ToXml() }) -join "`r`n") + "`r`n</Events>")
    $events | Select-Object @{N='UTC';E={$_.TimeCreated.ToUniversalTime().ToString('o')}},Id,RecordId,ProviderName,LevelDisplayName |
        Export-Csv -LiteralPath (Join-Path $out '03-WHEA-index.csv') -NoTypeInformation -Encoding UTF8
    Add-Status '03-WHEA' 'OK' ("Eventos exportados: "+$events.Count) $true
} catch {
    if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
        Write-Text (Join-Path $out '03-WHEA-raw.xml') '<Events />'
        Add-Status '03-WHEA' 'SIN_EVENTOS' 'Ningun evento WHEA-Logger en ESTA copia de System. No demuestra hardware sano.' $true
    } else {
        Write-Text (Join-Path $out '03-WHEA.error.txt') ($_ | Out-String)
        Add-Status '03-WHEA' 'ERROR' $_.Exception.Message $true
    }
}
Save-Read '04-hardware' {
    Get-CimInstance Win32_Processor | Select-Object Name,Manufacturer,NumberOfCores,NumberOfEnabledCore,NumberOfLogicalProcessors,ProcessorId,SocketDesignation,MaxClockSpeed | ConvertTo-Json -Depth 5
    Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model,NumberOfProcessors,NumberOfLogicalProcessors,TotalPhysicalMemory,PartOfDomain,Domain | ConvertTo-Json -Depth 5
    Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer,Product,SerialNumber,Version | ConvertTo-Json -Depth 5
    Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion,ReleaseDate,SerialNumber,Manufacturer,Version | ConvertTo-Json -Depth 5
    Get-CimInstance Win32_PhysicalMemory | Select-Object DeviceLocator,Capacity,PartNumber,SerialNumber,DataWidth,TotalWidth,Speed | ConvertTo-Json -Depth 5
} $true
Save-Read '05-windows' {
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture,InstallDate,LastBootUpTime | ConvertTo-Json -Depth 5
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Select-Object DisplayVersion,CurrentBuild,UBR,InstallDate,EditionID,BuildLabEx | ConvertTo-Json -Depth 5
} $true
$null = Invoke-ReadCommand '06-BCD' 'bcdedit.exe' '/enum all /v' $true
$null = Invoke-ReadCommand '07-planes' 'powercfg.exe' '/list' $true
$null = Invoke-ReadCommand '07-plan-activo' 'powercfg.exe' '/getactivescheme' $true
$null = Invoke-ReadCommand '07-energia-completa' 'powercfg.exe' '/qh SCHEME_CURRENT' $true
$null = Invoke-ReadCommand '07-suspension-disponible' 'powercfg.exe' '/a'
$null = Invoke-ReadCommand '07-solicitudes-energia' 'powercfg.exe' '/requests'
$null = Invoke-ReadCommand '08-paquetes-drivers' 'pnputil.exe' '/enum-drivers'
Save-Read '08-drivers-dispositivos' {
    Get-CimInstance Win32_PnPSignedDriver | Select-Object DeviceName,DeviceID,InfName,DriverVersion,DriverDate,DriverProviderName,IsSigned,Signer | ConvertTo-Json -Depth 5
}
Save-Read '08-drivers-cargados' { Get-CimInstance Win32_SystemDriver | Select-Object Name,State,StartMode,PathName | ConvertTo-Json -Depth 5 }
Read-RegTree '09-WU-politicas' 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
Read-RegTree '09-WU-MDM' 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\current\device\Update'
Read-RegTree '09-DeviceInstall' 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall'
Read-RegTree '09-DriverSearching' 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching'
Read-RegTree '09-WU-settings' 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
Save-Read '10-servicios' { Get-CimInstance Win32_Service | Select-Object Name,DisplayName,State,StartMode,PathName | ConvertTo-Json -Depth 5 }
Save-Read '10-tareas' { Get-ScheduledTask | Select-Object TaskPath,TaskName,State,Actions | ConvertTo-Json -Depth 7 }
Save-Read '11-software' {
    foreach ($key in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) {
        if (Test-Path -LiteralPath $key) {
            Get-ItemProperty ($key+'\*') | Select-Object DisplayName,DisplayVersion,Publisher,InstallDate | ConvertTo-Json -Depth 4
        }
    }
}
Save-Read '12-contadores' {
    Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation | Select-Object Name,PercentProcessorPerformance,PercentProcessorTime,ProcessorFrequency | ConvertTo-Json -Depth 4
    'Son una instantanea; NO miden tension real ni prueban ejecucion de todos los nucleos.'
}
$null = Invoke-ReadCommand '13-dominio-MDM' 'dsregcmd.exe' '/status'
$null = Invoke-ReadCommand '13-GPO' 'gpresult.exe' '/r /scope computer'
$null = Invoke-ReadCommand '14-BitLocker-estado-SIN-CLAVES' 'manage-bde.exe' '-status'
Save-Read '15-volcados-inventario' {
    foreach ($path in @("$env:SystemRoot\MEMORY.DMP","$env:SystemRoot\Minidump","$env:SystemRoot\LiveKernelReports")) {
        if (Test-Path -LiteralPath $path) {
            Get-ChildItem -LiteralPath $path -Recurse -File | Select-Object FullName,Length,LastWriteTimeUtc | ConvertTo-Json -Depth 5
        } else { 'AUSENTE: '+$path }
    }
    'Solo inventario: los volcados pueden contener secretos y deben preservarse aparte, con autorizacion.'
}
Copy-LiveFile "$env:SystemRoot\INF\setupapi.dev.log" '16-setupapi.dev.log'
Copy-LiveFile "$env:SystemRoot\INF\setupapi.dev.log.bak" '16-setupapi.dev.log.bak'
Copy-LiveFile "$env:SystemRoot\Panther\setupact.log" '16-Panther-setupact.log'
Copy-LiveFile "$env:SystemRoot\Panther\setuperr.log" '16-Panther-setuperr.log'
Copy-LiveFile "$env:SystemRoot\System32\Sysprep\Panther\setupact.log" '16-Sysprep-setupact.log'
Copy-LiveFile "$env:SystemRoot\System32\GroupPolicy\Machine\Registry.pol" '16-Registry.pol'
# Cerrar el registro de adquisicion ANTES de calcular el manifiesto.
$script:ledger | Export-Csv -LiteralPath (Join-Path $out 'ESTADOS.csv') -NoTypeInformation -Encoding UTF8
$criticalErrors = @($script:ledger | Where-Object { $_.required -and $_.state -in @('ERROR','TIMEOUT') })
$summary = [ordered]@{
    version='2.0';run_id=$runId;start_local=$start.ToString('o');end_utc=[DateTime]::UtcNow.ToString('o');
    scope='Adquisicion logica en vivo; no pruebas activas';critical_errors=$criticalErrors.Count;
    acquisition_gate=$(if ($criticalErrors.Count) {'INCOMPLETA_NO_AVANZAR'} else {'REVISAR_MANUALMENTE_ANTES_DE_AVANZAR'});
    windows_functional_validation='PENDIENTE';no_hardware_health_verdict=$true
}
Write-Text (Join-Path $out 'RESUMEN.json') ($summary | ConvertTo-Json -Depth 6)
$manifestRows = @(Get-ChildItem -LiteralPath $out -File | Where-Object { $_.Name -notin @('SHA256_manifest.csv','SHA256_manifest.sha256') } | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{File=$_.Name;Bytes=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
$manifestRows | Export-Csv -LiteralPath (Join-Path $out 'SHA256_manifest.csv') -NoTypeInformation -Encoding UTF8
$manifestHash = (Get-FileHash -LiteralPath (Join-Path $out 'SHA256_manifest.csv') -Algorithm SHA256).Hash
Write-Text (Join-Path $out 'SHA256_manifest.sha256') ($manifestHash+'  SHA256_manifest.csv')
Write-Host "Evidencia: $out"
Write-Host "Errores criticos: $($criticalErrors.Count). Revisar ESTADOS.csv. Esto NO certifica reparacion."
Write-Host 'No publicar los datos brutos ni ejecutar la prueba activa antigua.'
