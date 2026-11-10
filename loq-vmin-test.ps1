<#
  loq-vmin-test.ps1  -  OPTIONAL active test: does a CPU core throw hardware errors at its lowest voltage?

  WHAT IT DOES (about 23 minutes, plugged in):
    A0  3 min   normal settings                         -> expected: 0 WHEA errors
    B  15 min   CPU held at its LOWEST performance state -> a weak core starts logging WHEA 47 errors
    A1  5 min   normal settings again                   -> errors should stop
  A light load runs on EVERY logical CPU the whole time (fills a 32 KB buffer, sleeps 20 ms, verifies),
  so ANY weak core can show up, not just a particular one. The script decodes each new WHEA record live
  and reports which APIC id / physical core produced it, then writes an anonymized Markdown report.

  SAFETY DESIGN (read before running):
    * The low-voltage cap is applied IN MEMORY ONLY. The script sets the cap, activates it, and immediately
      writes your ORIGINAL values back to the registry without re-activating. Windows' power service reads
      the registry at boot, so if the PC crashes or reboots, it starts with your normal settings from the
      very first moment. The test values sit in the registry for ~0.1-0.2 s only (logged).
    * Phase B ends early after -StopAfter errors (default 3): enough to show the pattern, less crash risk.
    * It refuses to run on battery, or if it cannot verify that the registry holds your original values,
      or if the cap does not actually take effect.
    * It does NOT touch BIOS, drivers, voltages beyond Windows' normal range, or any file outside this folder.
  RISK: on an affected laptop the PC MAY CRASH (that is what you are testing). Save your work, close apps,
  keep the charger connected, do not close the lid. If it crashes, log in again and run:
        loq-vmin-test.ps1 -Report        (analyzes the interrupted run and writes the report)

  Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File .\loq-vmin-test.ps1 [-Rehearsal] [-Report] [-Yes]
          -Rehearsal : 3 x 1 min with a harmless 90 % cap (checks the mechanics, no low voltage)
  License: MIT. No warranty.
#>
param([int]$BaselineMin = 3, [int]$LowMin = 15, [int]$RecoveryMin = 5, [int]$StopAfter = 3, [int]$SleepMs = 20,
      [switch]$Rehearsal, [switch]$Report, [switch]$Yes)
$ErrorActionPreference = 'Continue'
$Version = '1.0.1'
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SUB = '54533251-82be-4824-96c1-47b60b740d00'; $MIN = '893dee8e-2bef-41e0-89c6-b55d0929964c'; $MAX = 'bc5038f7-23e0-4960-96da-33abaf5935ec'
$XPF = [Guid]'8a1e1d01-42f9-4557-9c33-565e5cc3f7e8'

# ---------------- helpers ----------------
function HexToBytes([string]$h) { $r = New-Object byte[] ($h.Length / 2); for ($i = 0; $i -lt $r.Length; $i++) { $r[$i] = [Convert]::ToByte($h.Substring(2 * $i, 2), 16) }; $r }
function ActiveScheme { $s = powercfg /getactivescheme | Out-String; ([regex]::Match($s, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')).Value }
function PlanAC([string]$scheme, [string]$set) { $q = powercfg /q $scheme $SUB $set | Out-String; $h = @([regex]::Matches($q, '0x[0-9a-fA-F]{8}') | ForEach-Object Value); if ($h.Count -ge 2) { [Convert]::ToInt32($h[-2], 16) } else { $null } }
function PerfMax { (Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation | Where-Object { $_.Name -notmatch '_Total' } | Measure-Object PercentProcessorPerformance -Maximum).Maximum }
function OnAC { Add-Type -AssemblyName System.Windows.Forms; [string]([Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus) -eq 'Online' }
$script:wheaReadError = $false
function Get-Whea([datetime]$from, [datetime]$to) {
  # A real read failure must not look like "0 errors" (that would be a false NEGATIVE).
  try { $evs = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $from; EndTime = $to } -ErrorAction Stop) }
  catch { if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { $script:wheaReadError = $true }; return @() }
  @($evs | ForEach-Object {
    $apic = $null; $unit = ''
    $raw = (([xml]$_.ToXml()).Event.EventData.Data | Where-Object Name -eq 'RawData').'#text'
    if ($raw -and $raw.Length -ge 256) { $b = HexToBytes $raw
      if ([Text.Encoding]::ASCII.GetString($b, 0, 4) -eq 'CPER') { $n = [BitConverter]::ToUInt16($b, 10)
        for ($i = 0; $i -lt $n; $i++) { $d = 128 + 72 * $i; if ($d + 72 -gt $b.Length) { break }
          if ((New-Object Guid (, [byte[]]$b[($d + 16)..($d + 31)])) -eq $XPF) { $o = [int][BitConverter]::ToUInt32($b, $d)
            if ($o + 80 -le $b.Length) { $apic = [int][BitConverter]::ToUInt32($b, $o + 68); $ip = [BitConverter]::ToUInt64($b, $o + 72)
              $unit = '0x{0:X}/0x{1:X}' -f (($ip -shr 32) -band 0xFFF), (($ip -shr 48) -band 0xFFFF) } } } } }
    [pscustomobject]@{ t = $_.TimeCreated; id = $_.Id; apic = $apic; unit = $unit } }) }
$tpcCpu = @(Get-CimInstance Win32_Processor)[0]
$TPC = if ($tpcCpu -and $tpcCpu.NumberOfCores -gt 0) { [Math]::Max(1, [int]($tpcCpu.NumberOfLogicalProcessors / $tpcCpu.NumberOfCores)) } else { 2 }
function UnitName($u) { switch ($u) { '0xB0/0x10' { 'LS_V2 (L1 data cache)' } '0xB0/0x0' { 'LS (L1 data)' } '0xB0/0x1' { 'IF (L1 instr.)' } '0xB0/0x2' { 'L2' } '0xB0/0x3' { 'DE (decode)' } '0xB0/0x5' { 'EX (execution)' } '0xB0/0x6' { 'FP' } '0xB0/0x7' { 'L3' } '0x96/0x0' { 'UMC (memory ctrl)' } '0x96/0x1' { 'UMC_V2 (memory ctrl)' } default { if ($u) { "other $u" } else { 'not decoded' } } } }
function DeviceId { $bios = Get-CimInstance Win32_BIOS; $mg = (Get-ItemProperty 'Registry::HKLM\SOFTWARE\Microsoft\Cryptography').MachineGuid
  (([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes("$($bios.SerialNumber)|$mg")) | Select-Object -First 4 | ForEach-Object { $_.ToString('x2') }) -join '') }
# durable logging: every line is flushed to disk immediately (survives a hard crash)
$script:fs = $null; $script:sw = $null
function Open-Log($path) { $script:fs = New-Object IO.FileStream($path, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite, 4096, [IO.FileOptions]::WriteThrough); $script:sw = New-Object IO.StreamWriter($script:fs, (New-Object Text.UTF8Encoding($false))) }
function W([string]$line) { if ($script:sw) { $script:sw.WriteLine($line); $script:sw.Flush(); $script:fs.Flush($true) } }
function Say([string]$msg) { $l = "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $msg; Write-Host $l; W "# $l" }

# ---------------- report (also used after a crash with -Report) ----------------
function Write-Report([string]$runFile) {
  $lines = Get-Content $runFile -Encoding UTF8
  $meta = @{}; $lines | Where-Object { $_ -match '^#META (\w+)=(.*)$' } | ForEach-Object { $meta[$Matches[1]] = $Matches[2] }
  $ph = @{}; $lines | Where-Object { $_ -match '^#PHASE (\w+) (start|end) (.+)$' } | ForEach-Object { if (-not $ph[$Matches[1]]) { $ph[$Matches[1]] = @{} }; $ph[$Matches[1]][$Matches[2]] = [datetime]::Parse($Matches[3], [Globalization.CultureInfo]::InvariantCulture) }
  $samples = @($lines | Where-Object { $_ -match '^\d{4}-' })
  $lastT = if ($samples.Count) { [datetime]::Parse(($samples[-1] -split ',')[0], [Globalization.CultureInfo]::InvariantCulture) } else { [datetime]::Parse($meta['start'], [Globalization.CultureInfo]::InvariantCulture) }
  $finished = [bool]($lines -match '^#FINISHED')
  $crashed = $false; $crashPhase = ''
  if (-not $finished) { $kp = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $lastT } -ErrorAction SilentlyContinue)
    if ($kp.Count) { $crashed = $true; foreach ($k in 'A0', 'B', 'A1') { if ($ph[$k] -and $ph[$k]['start'] -and -not $ph[$k]['end']) { $crashPhase = $k } } } }
  $rows = @(); $tot = @{}
  foreach ($k in 'A0', 'B', 'A1') {
    if (-not $ph[$k] -or -not $ph[$k]['start']) { $rows += "| $k | not reached | | | |"; continue }
    $s = $ph[$k]['start']; $e = if ($ph[$k]['end']) { $ph[$k]['end'] } else { $lastT }
    $w = Get-Whea $s $e; $tot[$k] = $w.Count
    $byApic = (@($w | Where-Object { $null -ne $_.apic } | Group-Object apic | Sort-Object Count -Descending | ForEach-Object { "APIC $($_.Name) (core $([Math]::Floor([int]$_.Name / $TPC))): $($_.Count)" }) -join ', ')
    $units = (@($w | Group-Object unit | ForEach-Object { "$(UnitName $_.Name) x$($_.Count)" }) -join ', ')
    $note = if ($crashed -and $crashPhase -eq $k) { ' **(crash during this phase)**' } else { '' }
    $rows += "| $k$note | {0:N1} min | {1} | {2} | {3} |" -f ($e - $s).TotalMinutes, $w.Count, $(if ($byApic) { $byApic } else { '-' }), $(if ($units) { $units } else { '-' })
  }
  $a0 = [int]$tot['A0']; $b = [int]$tot['B']; $a1 = [int]$tot['A1']
  $verdict = if ($script:wheaReadError -or $meta['whea_read_error'] -eq '1') { 'INCONCLUSIVE: the Windows event log could not be read, so missing errors cannot be ruled out. Run it again.' }
    elseif ($meta['mode'] -eq 'rehearsal') { 'REHEARSAL (harmless 90 % cap): mechanics checked, no low-voltage stimulus. Not a result.' }
    elseif ($b -gt 0 -and $a0 -eq 0 -and $a1 -eq 0) { 'POSITIVE: hardware errors appeared ONLY while the CPU was at its lowest voltage, and stopped afterwards. Consistent with a low-voltage (Vmin) defect in the core(s) listed above.' }
    elseif ($crashed -and $crashPhase -eq 'B' -and $a0 -eq 0) { 'POSITIVE (crash): the PC crashed while the CPU was at its lowest voltage, with no errors at normal settings.' }
    elseif ($b -eq 0 -and -not $crashed) { 'NEGATIVE: no hardware errors at the lowest voltage during this run.' }
    else { 'INCONCLUSIVE: errors also appeared at normal settings (or the run was interrupted early). Please share the report anyway.' }
  $md = @("# LOQ Vmin test report (loq-vmin-test v$Version)", '',
    "Date $($meta['start'].Substring(0,10)) | Device id: ``$($meta['device'])`` | Mode: $($meta['mode'])", '',
    '| Item | Value |', '|---|---|',
    "| model | $($meta['model']) |", "| bios | $($meta['bios']) |", "| cpu | $($meta['cpu']) |", "| windows | $($meta['windows']) |",
    "| original processor min / max (AC) | $($meta['origmin']) % / $($meta['origmax']) % |",
    "| test cap | $($meta['cap']) % (in memory only) |", "| registry held test values for | $($meta['window_ms']) ms |",
    "| max core performance at normal / during cap | $($meta['perf_normal']) % / $($meta['perf_cap']) % |", '',
    "## Result: $verdict", '',
    '| Phase | Duration | WHEA errors | By APIC id (likely physical core) | Reporting unit |', '|---|---|---|---|---|') + $rows + @('',
    "- Stimulus mismatches seen by the script itself (in-memory pattern check): $($meta['mismatch_total'])",
    "- Run finished normally: $finished | Crash detected (Kernel-Power 41 after the last sample): $crashed",
    '', '---', '*Please paste this report in a GitHub issue, even if the result is NEGATIVE: negative results matter as much as positive ones.*')
  $out = Join-Path $dir ("vmin-report-{0}-{1}.md" -f $meta['device'], ($meta['start'] -replace '[^0-9]', '').Substring(0, 12))
  $md -join "`r`n" | Out-File $out -Encoding utf8
  Write-Host ($md -join "`n"); Write-Host "`nSaved: $out" -ForegroundColor Green
}

if ($Report) {
  $last = Get-ChildItem $dir -Filter 'vmin-run-*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $last) { Write-Host 'No run log found next to this script.'; return }
  Write-Report $last.FullName; return
}

# ---------------- pre-flight ----------------
$scheme = ActiveScheme
$origMin = PlanAC $scheme $MIN; $origMax = PlanAC $scheme $MAX
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$nCpu = [Math]::Min([int]$cpu.NumberOfLogicalProcessors, 64)
$cap = if ($Rehearsal) { 90 } else { 5 }
$capMin = if ($Rehearsal) { [Math]::Min([int]$origMin, 90) } else { 5 }
if ($Rehearsal) { $BaselineMin = 1; $LowMin = 1; $RecoveryMin = 1 }
Write-Host "loq-vmin-test v$Version | CPU: $(($cpu.Name -replace '\s+',' ').Trim()) | logical CPUs: $nCpu | active plan: $scheme"
Write-Host "Original processor state (AC): min $origMin % / max $origMax % | Test cap: min $capMin % / max $cap % (memory only)"
if (-not $scheme -or $null -eq $origMin -or $null -eq $origMax) { Write-Host 'ABORT: could not read the active power plan.' -ForegroundColor Red; return }
if (-not (OnAC)) { Write-Host 'ABORT: connect the charger. This test only runs on AC power.' -ForegroundColor Red; return }
if ($cpu.Manufacturer -notmatch 'AMD') { Write-Host 'Note: WHEA decoding supports AMD only. The test still runs, but error locations will not be decoded.' -ForegroundColor Yellow }
if (-not $Yes) {
  Write-Host ''
  Write-Host 'EN: This test may CRASH your PC if a CPU core is defective. Save your work and close all apps.' -ForegroundColor Yellow
  Write-Host '    Keep the charger connected and do not close the lid. About 23 minutes. Settings are restored automatically.' -ForegroundColor Yellow
  Write-Host 'ES: Esta prueba puede COLGAR tu PC si un nucleo esta defectuoso. Guarda tu trabajo y cierra todo.' -ForegroundColor Yellow
  Write-Host '    Deja el cargador conectado y no cierres la tapa. Unos 23 minutos. La configuracion se restaura sola.' -ForegroundColor Yellow
  $ans = Read-Host 'Type YES / SI to start'
  if ($ans -notmatch '^(YES|SI|SÍ|yes|si|sí)$') { Write-Host 'Cancelled.'; return }
}

# ---------------- stimulus on every logical CPU ----------------
if (-not ('VminStim' -as [type])) {
Add-Type -TypeDefinition @'
using System; using System.Threading; using System.Runtime.InteropServices;
public static class VminStim {
  [DllImport("kernel32.dll")] static extern UIntPtr SetThreadAffinityMask(IntPtr h, UIntPtr mask);
  [DllImport("kernel32.dll")] static extern IntPtr GetCurrentThread();
  [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);
  static volatile bool run; static Thread[] ts;
  public static long[] Cycles; public static long[] Mismatch;
  public static void Start(int n, int sleepMs) {
    run = true; Cycles = new long[n]; Mismatch = new long[n]; ts = new Thread[n];
    for (int i = 0; i < n; i++) { int cpu = i; ts[i] = new Thread(() => Work(cpu, sleepMs)); ts[i].IsBackground = true; ts[i].Start(); }
  }
  static void Work(int cpu, int sleepMs) {
    SetThreadAffinityMask(GetCurrentThread(), (UIntPtr)(1UL << cpu));
    byte[] buf = new byte[32768]; byte p = (byte)(0x5A ^ cpu);
    while (run) {
      for (int k = 0; k < buf.Length; k++) buf[k] = (byte)(p + k);
      Thread.Sleep(sleepMs);
      for (int k = 0; k < buf.Length; k++) if (buf[k] != (byte)(p + k)) { Interlocked.Increment(ref Mismatch[cpu]); break; }
      Interlocked.Increment(ref Cycles[cpu]); p++;
    }
  }
  public static void Stop() { run = false; if (ts != null) foreach (Thread t in ts) t.Join(2000); }
  public static long Sum(long[] a) { long s = 0; if (a != null) foreach (long x in a) s += x; return s; }
}
'@
}

# ---------------- run ----------------
$start = Get-Date
$runFile = Join-Path $dir ("vmin-run-{0:yyyyMMdd-HHmmss}.log" -f $start)
Open-Log $runFile
$csp = Get-CimInstance Win32_ComputerSystemProduct; $cv = Get-ItemProperty 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
W "#META start=$($start.ToString('yyyy-MM-dd HH:mm:ss'))"; W "#META device=$(DeviceId)"; W "#META mode=$(if ($Rehearsal) { 'rehearsal' } else { 'full' })"
W "#META model=$($csp.Version) ($($csp.Name))"; W "#META bios=$((Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion)"; W "#META cpu=$(($cpu.Name -replace '\s+',' ').Trim())"
W "#META windows=$($cv.DisplayVersion) build $($cv.CurrentBuild).$($cv.UBR)"; W "#META origmin=$origMin"; W "#META origmax=$origMax"; W "#META cap=$cap"
W 'time,phase,perf_max_pct,whea_in_phase,stim_cycles,stim_mismatch,ac'
[VminStim]::SetThreadExecutionState([uint32]2147483649) | Out-Null    # ES_CONTINUOUS | ES_SYSTEM_REQUIRED: no idle sleep during the test
[VminStim]::Start($nCpu, $SleepMs)
$capApplied = $false
function RunPhase([string]$name, [int]$minutes, [int]$stopAfter) {
  $s = Get-Date; W "#PHASE $name start $($s.ToString('yyyy-MM-dd HH:mm:ss'))"; Say "Phase $name ($minutes min)"
  $end = $s.AddMinutes($minutes); $n = 0
  while ((Get-Date) -lt $end) {
    Start-Sleep -Seconds 5
    $n = (Get-Whea $s (Get-Date)).Count
    W ("{0:yyyy-MM-dd HH:mm:ss},{1},{2},{3},{4},{5},{6}" -f (Get-Date), $name, (PerfMax), $n, [VminStim]::Sum([VminStim]::Cycles), [VminStim]::Sum([VminStim]::Mismatch), [int](OnAC))
    if (-not (OnAC)) { Say 'Charger disconnected: ending the test early (restoring settings).'; break }
    if ($stopAfter -gt 0 -and $n -ge $stopAfter) { Say "$n hardware errors in phase $name : ending this phase early (enough evidence, less crash risk)."; break }
  }
  if ($script:wheaReadError) { W '#META whea_read_error=1' }
  W "#PHASE $name end $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"; Say "Phase $name done: $n WHEA error(s)."
}
try {
  W "#META perf_normal=$(PerfMax)"
  RunPhase 'A0' $BaselineMin 0
  # ---- apply the cap IN MEMORY, then put the original values back in the registry without activating ----
  $t0 = Get-Date
  powercfg /setacvalueindex $scheme $SUB $MIN $capMin | Out-Null
  powercfg /setacvalueindex $scheme $SUB $MAX $cap | Out-Null
  powercfg /setactive $scheme | Out-Null
  $capApplied = $true
  powercfg /setacvalueindex $scheme $SUB $MAX $origMax | Out-Null
  powercfg /setacvalueindex $scheme $SUB $MIN $origMin | Out-Null
  $win = [int]((Get-Date) - $t0).TotalMilliseconds; W "#META window_ms=$win"
  $rMin = PlanAC $scheme $MIN; $rMax = PlanAC $scheme $MAX
  Start-Sleep -Seconds 2; $pc = PerfMax; W "#META perf_cap=$pc"
  Say "Cap active in memory. Registry back to min $rMin % / max $rMax % (test values were stored for $win ms). Max core performance now $pc %."
  if ($rMin -ne $origMin -or $rMax -ne $origMax) { throw 'Registry does not hold the original values. Aborting.' }
  if (-not $Rehearsal -and ($null -eq $pc -or $pc -gt 60)) { throw "The cap did not take effect or could not be verified (performance '$pc' %). Possibly an overlay power mode or OEM tool. Aborting: nothing to test." }
  RunPhase 'B' $LowMin $StopAfter
  powercfg /setactive $scheme | Out-Null; $capApplied = $false
  Say "Normal settings re-activated. Max core performance: $(PerfMax) %."
  RunPhase 'A1' $RecoveryMin 0
  W "#META mismatch_total=$([VminStim]::Sum([VminStim]::Mismatch))"
  W '#FINISHED'
} catch {
  Say "STOPPED: $($_.Exception.Message)"
} finally {
  if ($capApplied) { powercfg /setactive $scheme | Out-Null }
  [VminStim]::Stop()
  [VminStim]::SetThreadExecutionState([uint32]2147483648) | Out-Null
  Say ("Settings restored. Registry min {0} % / max {1} %." -f (PlanAC $scheme $MIN), (PlanAC $scheme $MAX))
  if ($script:sw) { $script:sw.Close() }
}
Write-Report $runFile
