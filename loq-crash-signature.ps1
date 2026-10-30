<#
  loq-crash-signature.ps1  -  READ-ONLY check for the "weak CPU core at low voltage" (Vmin) failure pattern
  seen on Lenovo LOQ 15ARP9 (Ryzen 7 7435HS) and possibly other AMD Ryzen laptops.

  It changes NOTHING on your PC and needs no admin rights. It reads the Windows event logs and writes an
  anonymized Markdown report (+ JSON) that you can paste into a GitHub issue.

  Checks (all language-independent: event IDs and event fields, never message text):
    S1  WHEA-Logger 47 "corrected machine check" records decoded from the raw CPER/MCA data:
        reporting unit (AMD SMCA IPID) and APIC id. Flags errors concentrated on ONE physical core.
        (Not necessarily core 7: the tool tells you which core, if any.)
    S2  Windows labels them "Memory" although the RAM has no ECC and the unit is not the memory controller.
    S3  First boot after a clean shutdown fails far more often after >60 min off (cold) than <10 min (warm).
    S4  Crashes concentrated on battery relative to the time spent on battery.
    S5  Most crashes inside Modern Standby.
    S6  Applications crashing with 0xC000001D (illegal instruction) inside Windows system DLLs, which
        should never contain invalid instructions: a hint of instruction/data corruption in the CPU.
  Also reports the minimum processor state (AC/DC) of your active power plan, because a high AC minimum
  (e.g. 80 %) can hide a low-voltage defect while plugged in.

  Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File .\loq-crash-signature.ps1 [-Days 60]
  License: MIT. No warranty.
#>
param([int]$Days = 60, [string]$OutDir = '')
$ErrorActionPreference = 'SilentlyContinue'
$Version = '1.1.0'
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
if (-not $OutDir) { $OutDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$since = (Get-Date).AddDays(-$Days)

# ---------------- helpers ----------------
function LnFact([int]$n) { $s = 0.0; for ($i = 2; $i -le $n; $i++) { $s += [Math]::Log($i) }; $s }
function LnComb([int]$n, [int]$k) { if ($k -lt 0 -or $k -gt $n) { return [double]::NegativeInfinity }; (LnFact $n) - (LnFact $k) - (LnFact ($n - $k)) }
function FisherOneSided([int]$a, [int]$b, [int]$c, [int]$d) {   # P(X >= a) for the 2x2 table [[a,b],[c,d]]
  $n = $a + $b + $c + $d; $K = $a + $c; $N1 = $a + $b; $p = 0.0
  for ($x = $a; $x -le [Math]::Min($K, $N1); $x++) { $p += [Math]::Exp((LnComb $K $x) + (LnComb ($n - $K) ($N1 - $x)) - (LnComb $n $N1)) }
  [Math]::Min(1.0, $p) }
function BinomUpper([int]$n, [int]$k, [double]$p) { if ($p -le 0 -or $p -ge 1) { return [double]::NaN }; $s = 0.0; for ($i = $k; $i -le $n; $i++) { $s += [Math]::Exp((LnComb $n $i) + $i * [Math]::Log($p) + ($n - $i) * [Math]::Log(1 - $p)) }; [Math]::Min(1.0, $s) }
function HexToBytes([string]$h) { $r = New-Object byte[] ($h.Length / 2); for ($i = 0; $i -lt $r.Length; $i++) { $r[$i] = [Convert]::ToByte($h.Substring(2 * $i, 2), 16) }; $r }
function EvData($e) { $d = @{}; ([xml]$e.ToXml()).Event.EventData.Data | ForEach-Object { if ($_.Name) { $d[$_.Name] = $_.'#text' } }; $d }
function SmcaName([int]$hwid, [int]$type) {
  $t = @{ '176-0'='LS (core load-store / L1 data)'; '176-16'='LS_V2 (core load-store / L1 data cache)'; '176-1'='IF (core instruction fetch / L1 instr.)'; '176-2'='L2 cache (core)';
          '176-3'='DE (core decode)'; '176-5'='EX (core execution)'; '176-6'='FP (core floating point)'; '176-7'='L3 cache'; '150-0'='UMC (DRAM memory controller)'; '150-1'='UMC_V2 (DRAM memory controller)' }
  $k = "$hwid-$type"; if ($t.ContainsKey($k)) { $t[$k] } else { "other (HWID 0x{0:X}, McaType 0x{1:X})" -f $hwid, $type } }
function Fmt($x) { if ($null -eq $x -or [double]::IsNaN([double]$x)) { 'n/a' } else { '{0:G3}' -f $x } }
function PlanIndex([string]$sub, [string]$set) {   # current AC/DC index of a setting in the active plan (language-independent: last two hex values)
  $q = powercfg /q SCHEME_CURRENT $sub $set | Out-String
  $h = @([regex]::Matches($q, '0x[0-9a-fA-F]{8}') | ForEach-Object Value)
  if ($h.Count -ge 2) { @{ AC = [Convert]::ToInt32($h[-2], 16); DC = [Convert]::ToInt32($h[-1], 16) } } else { @{ AC = $null; DC = $null } } }
$XPF_MCA = [Guid]'8a1e1d01-42f9-4557-9c33-565e5cc3f7e8'

# ---------------- system (no serial number in the output) ----------------
$csp  = Get-CimInstance Win32_ComputerSystemProduct
$bios = Get-CimInstance Win32_BIOS
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$cv   = Get-ItemProperty 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$mem  = @(Get-CimInstance Win32_PhysicalMemory)
$mg   = (Get-ItemProperty 'Registry::HKLM\SOFTWARE\Microsoft\Cryptography').MachineGuid
# Device id = SHA-256(serial + random MachineGuid): stable per PC (spots duplicate reports), not reversible to the serial.
$sha  = [Security.Cryptography.SHA256]::Create()
$hash = (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("$($bios.SerialNumber)|$mg")) | Select-Object -First 4 | ForEach-Object { $_.ToString('x2') }) -join '')
$ecc  = if ($mem.Count -and ($mem | Where-Object { $_.TotalWidth -gt $_.DataWidth })) { 'yes' } else { 'no (DataWidth = TotalWidth)' }
$isAmd = $cpu.Manufacturer -match 'AMD'
$pmin = PlanIndex '54533251-82be-4824-96c1-47b60b740d00' '893dee8e-2bef-41e0-89c6-b55d0929964c'
$pmax = PlanIndex '54533251-82be-4824-96c1-47b60b740d00' 'bc5038f7-23e0-4960-96da-33abaf5935ec'
$sys = [ordered]@{
  model = "$($csp.Version) ($($csp.Name))"; bios = $bios.SMBIOSBIOSVersion; cpu = ($cpu.Name -replace '\s+', ' ').Trim()
  cores = "$($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads"
  windows = "$($cv.DisplayVersion) build $($cv.CurrentBuild).$($cv.UBR)"
  ram = (($mem | ForEach-Object { "{0} {1}GB" -f ([string]$_.PartNumber).Trim(), [int]($_.Capacity / 1GB) }) -join ' + ')
  ram_ecc = $ecc
  processor_min_state = "AC $($pmin.AC) % / DC $($pmin.DC) %"
  processor_max_state = "AC $($pmax.AC) % / DC $($pmax.DC) %"
  device_id = $hash }
$logStart = (Get-WinEvent -LogName System -MaxEvents 1 -Oldest).TimeCreated
if ($logStart -gt $since) { $since = $logStart }

# ---------------- S1/S2: WHEA decode ----------------
$whea = @()
foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $since })) {
  $row = [ordered]@{ time = $e.TimeCreated; id = $e.Id; bank = $null; unit = ''; apic = $null; cecc = $null; uc = $null }
  $raw = (EvData $e)['RawData']
  if ($raw -and $raw.Length -ge 256) {
    $b = HexToBytes $raw
    if ([Text.Encoding]::ASCII.GetString($b, 0, 4) -eq 'CPER') {
      $n = [BitConverter]::ToUInt16($b, 10)
      for ($i = 0; $i -lt $n; $i++) {
        $dsc = 128 + 72 * $i; if ($dsc + 72 -gt $b.Length) { break }
        $g = New-Object Guid (, [byte[]]$b[($dsc + 16)..($dsc + 31)])
        if ($g -eq $XPF_MCA) {
          $o = [int][BitConverter]::ToUInt32($b, $dsc)
          if ($o + 80 -le $b.Length) {
            $status = [BitConverter]::ToUInt64($b, $o + 40); $ipid = [BitConverter]::ToUInt64($b, $o + 72)
            $row.bank = [int][BitConverter]::ToUInt32($b, $o + 36); $row.apic = [int][BitConverter]::ToUInt32($b, $o + 68)
            $row.unit = SmcaName ([int](($ipid -shr 32) -band 0xFFF)) ([int](($ipid -shr 48) -band 0xFFFF))
            $row.cecc = [int](($status -shr 46) -band 1); $row.uc = [int](($status -shr 61) -band 1)
          } } } } }
  $whea += [pscustomobject]$row
}
$decoded = @($whea | Where-Object { $null -ne $_.apic })
$apicGroups = @($decoded | Group-Object apic | Sort-Object Count -Descending)
$unitGroups = @($decoded | Group-Object unit | Sort-Object Count -Descending)
$coreGroups = @($decoded | Group-Object { [int][Math]::Floor($_.apic / 2) } | Sort-Object Count -Descending)
$topCore = if ($coreGroups.Count) { [int]$coreGroups[0].Name } else { $null }
$topCoreShare = if ($decoded.Count) { [Math]::Round(100.0 * $coreGroups[0].Count / $decoded.Count, 1) } else { 0 }
$wheaMemLabel = @($whea | Where-Object { $_.id -eq 47 }).Count   # WHEA 47 = corrected error with a physical address, shown as "Memory"

# ---------------- S3-S5: power/boot timeline (event IDs and fields only) ----------------
$ev = Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $since } | Where-Object {
  ($_.ProviderName -eq 'Microsoft-Windows-Kernel-Power' -and $_.Id -in 105, 506, 507) -or
  ($_.ProviderName -eq 'Microsoft-Windows-Kernel-General' -and $_.Id -in 12, 13) -or
  ($_.ProviderName -eq 'Microsoft-Windows-Kernel-Boot' -and $_.Id -eq 20) } | Sort-Object TimeCreated
$ac = $true; $on = $true; $ms = $false; $cleanOff = $false; $last = $null; $lastOff = $null
$hours = @{ AC = 0.0; DC = 0.0 }; $crashes = @(); $boots = @()
foreach ($e in $ev) {
  $t = $e.TimeCreated
  if ($last -and $on) { $hours[$(if ($ac) { 'AC' } else { 'DC' })] += ($t - $last).TotalHours }
  switch ("$($e.ProviderName)|$($e.Id)") {
    'Microsoft-Windows-Kernel-Power|105' { $ac = ((EvData $e)['AcOnline'] -eq 'true') }
    'Microsoft-Windows-Kernel-Power|506' { $ms = $true }
    'Microsoft-Windows-Kernel-Power|507' { $ms = $false }
    'Microsoft-Windows-Kernel-General|13' { $on = $false; $cleanOff = $true; $lastOff = $t }
    'Microsoft-Windows-Kernel-General|12' {
      # a boot that was NOT preceded by a clean shutdown = the previous session ended in a crash/hang
      if ($last -and -not $cleanOff) { $crashes += [pscustomobject]@{ before = $t; ac = $ac; ms = $ms } }
      $on = $true; $ms = $false; $cleanOff = $false }
    'Microsoft-Windows-Kernel-Boot|20' {
      $d = EvData $e
      $off = if ($lastOff) { ($t - $lastOff).TotalMinutes } else { $null }
      if ($null -ne $off) { $boots += [pscustomobject]@{ t = $t; offMin = $off; ok = ($d['LastBootGood'] -eq 'true') } }
      $lastOff = $null }
  }
  $last = $t
}
$cAC = @($crashes | Where-Object ac).Count; $cDC = @($crashes | Where-Object { -not $_.ac }).Count; $cMS = @($crashes | Where-Object ms).Count
$totH = $hours.AC + $hours.DC
$pBatt = if ($totH -gt 0 -and $crashes.Count) { BinomUpper $crashes.Count $cDC ($hours.DC / $totH) } else { [double]::NaN }
$warm = @($boots | Where-Object { $_.offMin -lt 10 }); $cold = @($boots | Where-Object { $_.offMin -ge 60 })
$warmF = @($warm | Where-Object { -not $_.ok }).Count; $coldF = @($cold | Where-Object { -not $_.ok }).Count
$pCold = if ($cold.Count -and $warm.Count) { FisherOneSided $coldF ($cold.Count - $coldF) $warmF ($warm.Count - $warmF) } else { [double]::NaN }
$kp41 = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $since })
$bugcodes = @($kp41 | ForEach-Object { '0x{0:X}' -f [int64]((EvData $_)['BugcheckCode']) } | Group-Object | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) x$($_.Count)" })

# ---------------- S6: illegal-instruction crashes inside system DLLs ----------------
$ill = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'Application Error'; Id = 1000; StartTime = $since } | ForEach-Object {
  $d = @(([xml]$_.ToXml()).Event.EventData.Data | ForEach-Object { $_.'#text' })
  if ($d.Count -ge 7 -and $d[6] -match 'c000001d') { [pscustomobject]@{ t = $_.TimeCreated; module = $d[3] } } })
$illSys = @($ill | Where-Object { $_.module -match '^(ntdll|kernel32|kernelbase|ucrtbase|msvcrt|user32|win32u|combase|rpcrt4)\.dll$' })

# ---------------- verdict ----------------
$sig = @()
if ($decoded.Count -ge 5 -and $topCoreShare -ge 80 -and ($unitGroups[0].Name -match '^(LS|IF|L2|DE|EX|FP)')) { $sig += "S1 MCA errors concentrated on one physical core: core $topCore ($topCoreShare % of $($decoded.Count) records), unit $($unitGroups[0].Name)" }
if ($wheaMemLabel -gt 0 -and $ecc -like 'no*' -and $unitGroups.Count -and ($unitGroups[0].Name -notmatch 'UMC')) { $sig += 'S2 Windows shows these as "Memory" errors, but the RAM has no ECC and the reporting unit is a CPU core, not the memory controller' }
if ($cold.Count -ge 3 -and $coldF -ge 2 -and $pCold -lt 0.05) { $sig += "S3 first boot fails after a cold start ($coldF/$($cold.Count) cold vs $warmF/$($warm.Count) warm, p=$(Fmt $pCold))" }
if ($cDC -ge 2 -and $pBatt -lt 0.05) { $sig += "S4 crashes concentrated on battery ($cDC of $($crashes.Count) crashes in $([Math]::Round(100*$hours.DC/$totH,1)) % of powered-on time, p=$(Fmt $pBatt))" }
if ($crashes.Count -ge 3 -and $cMS -ge [Math]::Ceiling($crashes.Count / 2)) { $sig += "S5 most crashes inside Modern Standby ($cMS of $($crashes.Count))" }
if ($illSys.Count -ge 1) { $sig += "S6 $($illSys.Count) app crash(es) with 0xC000001D (illegal instruction) inside Windows system DLLs" }

# ---------------- report ----------------
$md = @()
$md += "# LOQ crash signature report (read-only check v$Version)"
$md += ''
$md += "Generated $(Get-Date -Format 'yyyy-MM-dd') | Event log window: $($since.ToString('yyyy-MM-dd')) to $(Get-Date -Format 'yyyy-MM-dd') | Device id: ``$hash``"
$md += ''
$md += '| Item | Value |'; $md += '|---|---|'
$sys.GetEnumerator() | Where-Object { $_.Key -ne 'device_id' } | ForEach-Object { $md += "| $($_.Key) | $($_.Value) |" }
$md += ''
$md += "## Signatures found: $($sig.Count) of 6"
if ($sig.Count) { $sig | ForEach-Object { $md += "- **$_**" } } else { $md += '- none' }
if (-not $isAmd) { $md += '- Note: MCA decoding in this tool supports AMD (SMCA) only; WHEA details on this CPU are not decoded.' }
$md += ''
$md += '## 1. WHEA hardware errors (S1, S2)'
$md += "- WHEA events: $($whea.Count) | WHEA 47 (shown as 'Memory' by Windows): $wheaMemLabel | decoded MCA records: $($decoded.Count)"
if ($decoded.Count) {
  $md += ''; $md += '| Reporting unit (AMD SMCA) | Count |'; $md += '|---|---|'; $unitGroups | ForEach-Object { $md += "| $($_.Name) | $($_.Count) |" }
  $md += ''; $md += '| APIC id | Likely physical core (APIC/2) | Count |'; $md += '|---|---|---|'; $apicGroups | ForEach-Object { $md += "| $($_.Name) | $([Math]::Floor([int]$_.Name / 2)) | $($_.Count) |" }
  $srt = @($decoded | Sort-Object time)
  $md += ''; $md += "- Corrected (CECC): $(@($decoded | Where-Object { $_.cecc -eq 1 }).Count) | Uncorrected: $(@($decoded | Where-Object { $_.uc -eq 1 }).Count) | First: $($srt[0].time.ToString('yyyy-MM-dd')) | Last: $($srt[-1].time.ToString('yyyy-MM-dd'))"
}
$md += ''
$md += '## 2. Unexpected shutdowns (S4, S5)'
$md += "- Kernel-Power 41: $($kp41.Count) | Bugcheck codes: $(if ($bugcodes) { $bugcodes -join ', ' } else { 'n/a' })"
$md += "- Sessions that ended without a clean shutdown: $($crashes.Count) | power state at the last logged event: on AC $cAC, on battery $cDC, in Modern Standby $cMS"
$md += "- Powered-on hours (approx.): AC $([Math]::Round($hours.AC,1)) h, battery $([Math]::Round($hours.DC,1)) h | crash rate AC $(if ($hours.AC) { '{0:N3}' -f ($cAC/$hours.AC) } else { 'n/a' })/h, battery $(if ($hours.DC) { '{0:N3}' -f ($cDC/$hours.DC) } else { 'n/a' })/h | p (battery concentration) = $(Fmt $pBatt)"
$md += ''
$md += '## 3. First boot after a clean shutdown (S3)'
$md += '| Time off | Boots | First attempt failed |'; $md += '|---|---|---|'
$md += "| < 10 min (warm) | $($warm.Count) | $warmF |"; $md += "| >= 60 min (cold) | $($cold.Count) | $coldF |"
$md += "- Fisher exact test (one-sided) p = $(Fmt $pCold)"
$md += ''
$md += '## 4. Illegal-instruction app crashes (S6)'
$md += "- 0xC000001D crashes: $($ill.Count) (inside system DLLs: $($illSys.Count))$(if ($ill.Count) { ' | modules: ' + ((@($ill | Group-Object module | ForEach-Object { "$($_.Name) x$($_.Count)" })) -join ', ') })"
$md += ''
$md += '---'
$md += '*Read-only check. S1+S2 point to one defective CPU core (on these laptops the APU is soldered: mainboard replacement), not to RAM. S3-S6 are patterns, not proof on their own. To confirm a low-voltage (Vmin) defect, run the optional `loq-vmin-test.ps1`. One report is one data point: please share yours.*'
$base = Join-Path $OutDir "loq-report-$hash"
$md -join "`r`n" | Out-File "$base.md" -Encoding utf8
[ordered]@{ tool = "loq-crash-signature $Version"; system = $sys; window_start = $since.ToString('yyyy-MM-dd'); signatures = $sig
  whea_total = $whea.Count; whea_decoded = $decoded.Count; top_core = $topCore; top_core_share = $topCoreShare
  units = @($unitGroups | ForEach-Object { @{ unit = $_.Name; n = $_.Count } }); apic = @($apicGroups | ForEach-Object { @{ apic = [int]$_.Name; n = $_.Count } })
  crashes = @{ total = $crashes.Count; ac = $cAC; battery = $cDC; standby = $cMS; hours_ac = [Math]::Round($hours.AC,1); hours_battery = [Math]::Round($hours.DC,1); p_battery = $pBatt }
  boots = @{ warm = $warm.Count; warm_failed = $warmF; cold = $cold.Count; cold_failed = $coldF; p_cold = $pCold }
  illegal_instruction = @{ total = $ill.Count; in_system_dlls = $illSys.Count } } | ConvertTo-Json -Depth 5 | Out-File "$base.json" -Encoding utf8
Write-Host ($md -join "`n")
Write-Host "`nSaved: $base.md (paste it in a GitHub issue) and $base.json" -ForegroundColor Green
