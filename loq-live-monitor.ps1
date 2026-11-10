<#
  loq-live-monitor.ps1  -  Live view of CPU hardware errors (WHEA), per core.   READ-ONLY.
  Panel en vivo de errores de hardware del CPU (WHEA), por núcleo.               SOLO LECTURA.

  It changes nothing: it reads the Windows event log every few seconds and shows, in a big
  green/red panel, how many hardware errors appeared, on which core and in which CPU unit,
  plus the current phase of loq-vmin-test.ps1 if that test is running next to it.
  Closing this window does not affect the test.

  Usage / Uso:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\loq-live-monitor.ps1 [-Since 'yyyy-MM-dd HH:mm:ss'] [-RunLog <vmin-run-*.log>] [-Once] [-Lang en|es]

    -Since   show errors from this moment (default: now)
    -RunLog  follow a specific vmin-run-*.log (default: the newest one next to this script, written after -Since)
    -Once    draw once and exit
    -Lang    interface language (default: Spanish if Windows is in Spanish, otherwise English)

  License: MIT. No warranty.
#>
param([string]$Since = '', [string]$RunLog = '', [switch]$Once, [int]$Every = 3, [ValidateSet('', 'en', 'es')][string]$Lang = '')
$ErrorActionPreference = 'Continue'
$Version = '1.0.0'
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
$inv = [Globalization.CultureInfo]::InvariantCulture
$start = if ($Since) { [datetime]::Parse($Since, $inv) } else { Get-Date }
$dir = $PSScriptRoot
$XPF = [Guid]'8a1e1d01-42f9-4557-9c33-565e5cc3f7e8'
if (-not $Lang) { $Lang = if ((Get-UICulture).TwoLetterISOLanguageName -eq 'es') { 'es' } else { 'en' } }
$T = @{
  en = @{ title = 'LOQ LIVE MONITOR (read-only)'; since = 'watching since'; phase = 'Test phase'; perf = 'CPU performance'; ac = 'Charger';
    acOn = 'connected'; acOff = 'DISCONNECTED'; capOn = '(lowest voltage: cap active)'; capOff = '(normal)'; na = 'n/a';
    ok = 'NO HARDWARE ERRORS'; bad = 'HARDWARE ERRORS'; core = 'core'; last = 'Latest errors:'; ev = 'event';
    wait = 'waiting for loq-vmin-test.ps1 to start'; prep = 'preparing'; done = 'TEST FINISHED'; ended = 'end of phase';
    A0 = 'A0 - normal settings (baseline)'; B = 'B - CPU AT LOWEST VOLTAGE (a weak core shows up here)'; A1 = 'A1 - normal settings again';
    byPhase = 'Errors by phase:'; outside = 'outside the test'; readErr = 'CANNOT READ THE EVENT LOG - error count NOT reliable';
    foot = 'Read-only: this window only reads the Windows event log. Closing it does not affect the test.'; min = 'min';
    units = @{ '0xB0/0x10' = 'L1 data cache (LS_V2)'; '0xB0/0x0' = 'L1 data cache (LS)'; '0xB0/0x1' = 'L1 instruction cache (IF)'; '0xB0/0x2' = 'L2 cache'; '0xB0/0x3' = 'decode unit (DE)'; '0xB0/0x5' = 'execution unit (EX)'; '0xB0/0x6' = 'floating point (FP)'; '0xB0/0x7' = 'L3 cache'; '0x96/0x0' = 'memory controller (UMC)'; '0x96/0x1' = 'memory controller (UMC)' }
    other = 'other unit'; undecoded = 'not decoded' }
  es = @{ title = 'MONITOR EN VIVO LOQ (solo lectura)'; since = 'mirando desde'; phase = 'Fase de la prueba'; perf = 'Rendimiento CPU'; ac = 'Cargador';
    acOn = 'conectado'; acOff = 'DESCONECTADO'; capOn = '(voltaje mínimo: tope activo)'; capOff = '(normal)'; na = 's/d';
    ok = 'SIN ERRORES DE HARDWARE'; bad = 'ERRORES DE HARDWARE'; core = 'núcleo'; last = 'Últimos errores:'; ev = 'evento';
    wait = 'esperando que arranque loq-vmin-test.ps1'; prep = 'preparando'; done = 'PRUEBA TERMINADA'; ended = 'fin de fase';
    A0 = 'A0 - configuración normal (referencia)'; B = 'B - CPU AL VOLTAJE MÍNIMO (aquí aparece un núcleo débil)'; A1 = 'A1 - configuración normal otra vez';
    byPhase = 'Errores por fase:'; outside = 'fuera de la prueba'; readErr = 'NO SE PUEDE LEER EL REGISTRO - conteo NO confiable';
    foot = 'Solo lectura: esta ventana solo lee el registro de Windows. Cerrarla no afecta la prueba.'; min = 'min';
    units = @{ '0xB0/0x10' = 'caché L1 de datos (LS_V2)'; '0xB0/0x0' = 'caché L1 de datos (LS)'; '0xB0/0x1' = 'caché L1 de instrucciones (IF)'; '0xB0/0x2' = 'caché L2'; '0xB0/0x3' = 'decodificador (DE)'; '0xB0/0x5' = 'unidad de ejecución (EX)'; '0xB0/0x6' = 'coma flotante (FP)'; '0xB0/0x7' = 'caché L3'; '0x96/0x0' = 'controlador de memoria (UMC)'; '0x96/0x1' = 'controlador de memoria (UMC)' }
    other = 'otra unidad'; undecoded = 'sin decodificar' }
}[$Lang]
try { $Host.UI.RawUI.WindowTitle = "$($T.title) v$Version" } catch {}

# Threads per core: APIC ids are consecutive per core on AMD, so core = apic / threadsPerCore.
$cpu = @(Get-CimInstance Win32_Processor)[0]
$tpc = if ($cpu -and $cpu.NumberOfCores -gt 0) { [Math]::Max(1, [int]($cpu.NumberOfLogicalProcessors / $cpu.NumberOfCores)) } else { 2 }

function HexToBytes([string]$h) { $r = New-Object byte[] ($h.Length / 2); for ($i = 0; $i -lt $r.Length; $i++) { $r[$i] = [Convert]::ToByte($h.Substring(2 * $i, 2), 16) }; $r }
$script:readError = $false
function Get-Whea([datetime]$from, [datetime]$to) {
  $script:readError = $false
  try { $evs = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $from; EndTime = $to } -ErrorAction Stop) }
  catch { if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { $script:readError = $true }; return @() }
  @($evs | ForEach-Object {
    $apic = $null; $unit = ''
    $raw = (([xml]$_.ToXml()).Event.EventData.Data | Where-Object Name -eq 'RawData').'#text'
    if ($raw -and $raw.Length -ge 256) { $b = HexToBytes $raw
      if ([Text.Encoding]::ASCII.GetString($b, 0, 4) -eq 'CPER') { $n = [BitConverter]::ToUInt16($b, 10)
        for ($i = 0; $i -lt $n; $i++) { $d = 128 + 72 * $i; if ($d + 72 -gt $b.Length) { break }
          if ((New-Object Guid (, [byte[]]$b[($d + 16)..($d + 31)])) -eq $XPF) { $o = [int][BitConverter]::ToUInt32($b, $d)
            if ($o + 80 -le $b.Length) { $apic = [int][BitConverter]::ToUInt32($b, $o + 68); $ip = [BitConverter]::ToUInt64($b, $o + 72)
              $unit = '0x{0:X}/0x{1:X}' -f (($ip -shr 32) -band 0xFFF), (($ip -shr 48) -band 0xFFFF) } } } } }
    [pscustomobject]@{ t = $_.TimeCreated; id = $_.Id; apic = $apic; unit = $unit } }) | Sort-Object t
}
function UnitName($u) { if ($T.units.ContainsKey([string]$u)) { $T.units[[string]$u] } elseif ($u) { "$($T.other) $u" } else { $T.undecoded } }
function CoreOf($apic) { if ($null -eq $apic) { '?' } else { [string][Math]::Floor($apic / $tpc) } }
function PerfMax { $v = (Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '_Total' } | Measure-Object PercentProcessorPerformance -Maximum).Maximum; if ($v) { [int]$v } else { $null } }
function OnAC { try { Add-Type -AssemblyName System.Windows.Forms; [string]([Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus) -eq 'Online' } catch { $null } }

# Phases of loq-vmin-test.ps1, read from its durable run log (#PHASE <name> start|end <time>, #FINISHED)
function Read-Run {
  $f = if ($RunLog) { Get-Item $RunLog -ErrorAction SilentlyContinue } else {
    Get-ChildItem $dir -Filter 'vmin-run-*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $start.AddMinutes(-1) } | Sort-Object LastWriteTime | Select-Object -Last 1 }
  if (-not $f) { return $null }
  $lines = @(Get-Content $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)
  $ph = [ordered]@{}; $order = @()
  foreach ($l in $lines) { if ($l -match '^#PHASE (\w+) (start|end) (.+)$') { $k = $Matches[1]; if (-not $ph.Contains($k)) { $ph[$k] = @{}; $order += $k }; $ph[$k][$Matches[2]] = [datetime]::Parse($Matches[3], $inv) } }
  [pscustomobject]@{ phases = $ph; order = $order; finished = [bool]($lines -match '^#FINISHED') }
}

function Banner([string]$text, [string]$bg) {
  $w = 100; try { $w = [Math]::Max(60, [Math]::Min(110, $Host.UI.RawUI.WindowSize.Width - 1)) } catch {}
  if ($text.Length -gt $w) { $text = $text.Substring(0, $w) }
  $pad = ' ' * [Math]::Max(0, [int](($w - $text.Length) / 2))
  Write-Host (' ' * $w) -BackgroundColor $bg; Write-Host (($pad + $text).PadRight($w)) -BackgroundColor $bg -ForegroundColor White; Write-Host (' ' * $w) -BackgroundColor $bg
}

do {
  $now = Get-Date
  $run = Read-Run
  # A finished run is shown as it ended (window = start .. end of its last phase + 1 min); otherwise up to now.
  $to = $now
  if ($run -and $run.finished -and $run.order.Count) { $lastPh = $run.phases[$run.order[-1]]; if ($lastPh['end']) { $to = $lastPh['end'].AddMinutes(1) } }
  $ev = @(Get-Whea $start $to)
  $perf = PerfMax; $ac = OnAC

  # current phase text
  $phaseTxt = $T.wait; $inB = $false
  if ($run) {
    if ($run.finished) { $phaseTxt = $T.done }
    elseif (-not $run.order.Count) { $phaseTxt = $T.prep }
    else { $k = $run.order[-1]; $p = $run.phases[$k]
      if ($p['end']) { $phaseTxt = "$($T.ended) $k" }
      else { $phaseTxt = ('{0}   ({1:N1} {2})' -f $T[$k], ($now - $p['start']).TotalMinutes, $T.min); $inB = ($k -eq 'B') } }
  }

  Clear-Host
  Write-Host ('{0}   {1:HH:mm:ss}   {2} {3:yyyy-MM-dd HH:mm:ss}' -f $T.title, $now, $T.since, $start) -ForegroundColor Cyan
  Write-Host ''
  Write-Host ('  {0,-18}: {1}' -f $T.phase, $phaseTxt) -ForegroundColor $(if ($inB) { 'Yellow' } else { 'Gray' })
  $perfTxt = if ($null -eq $perf) { $T.na } else { '{0} %   {1}' -f $perf, $(if ($perf -le 60) { $T.capOn } else { $T.capOff }) }
  Write-Host ('  {0,-18}: {1}' -f $T.perf, $perfTxt) -ForegroundColor Gray
  $acTxt = if ($null -eq $ac) { $T.na } elseif ($ac) { $T.acOn } else { $T.acOff }
  Write-Host ('  {0,-18}: {1}' -f $T.ac, $acTxt) -ForegroundColor $(if ($ac -eq $false) { 'Red' } else { 'Gray' })
  Write-Host ''

  if ($script:readError) { Banner $T.readErr 'DarkYellow' }
  elseif ($ev.Count -eq 0) { Banner $T.ok 'DarkGreen' }
  else {
    $byCore = @($ev | Group-Object { CoreOf $_.apic } | Sort-Object Count -Descending | ForEach-Object { "$($T.core) $($_.Name): $($_.Count)" }) -join '   '
    Banner ('{0} {1}   {2}' -f $ev.Count, $T.bad, $byCore) 'DarkRed'
  }

  if ($run -and $run.order.Count) {
    Write-Host ''
    Write-Host ('  ' + $T.byPhase) -ForegroundColor White
    $inside = 0
    foreach ($k in $run.order) { $p = $run.phases[$k]; $e = if ($p['end']) { $p['end'] } else { $to }
      $w = @($ev | Where-Object { $_.t -ge $p['start'] -and $_.t -lt $e }); $inside += $w.Count
      $cores = @($w | Group-Object { CoreOf $_.apic } | ForEach-Object { "$($T.core) $($_.Name): $($_.Count)" }) -join ', '
      Write-Host ('    {0,-3} {1,6:N1} {2}   {3,3}   {4}' -f $k, ($e - $p['start']).TotalMinutes, $T.min, $w.Count, $cores) -ForegroundColor $(if ($w.Count) { 'Red' } else { 'Green' }) }
    if ($ev.Count - $inside) { Write-Host ('    {0}: {1}' -f $T.outside, ($ev.Count - $inside)) -ForegroundColor DarkYellow }
  }

  if ($ev.Count) {
    Write-Host ''
    Write-Host ('  ' + $T.last) -ForegroundColor White
    $ev | Select-Object -Last 8 | ForEach-Object {
      $where = if ($null -ne $_.apic) { '{0} {1} (APIC {2})' -f $T.core, (CoreOf $_.apic), $_.apic } else { "$($T.core) ?" }
      Write-Host ('    {0:HH:mm:ss}  {1} {2}  {3,-22}  {4}' -f $_.t, $T.ev, $_.id, $where, (UnitName $_.unit)) -ForegroundColor Red }
  }
  Write-Host ''
  Write-Host ('  ' + $T.foot) -ForegroundColor DarkGray
  if (-not $Once) { Start-Sleep -Seconds $Every }
} while (-not $Once)
