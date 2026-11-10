# Changelog

## 2026-11-10
- **New: `loq-live-monitor.ps1` v1.0.0**: read-only live panel (green/red) with WHEA errors per core and per test phase. `RUN-VMIN-TEST.cmd` opens it automatically.
- **`loq-vmin-test.ps1` v1.0.1** (audit fixes):
  - If the Windows event log cannot be read, the result is now **INCONCLUSIVE** instead of a false NEGATIVE (before, a read failure looked like "0 errors").
  - Phase B aborts if the low-voltage cap **cannot be verified** (the performance counter is missing). Before, a missing counter let the test run uncapped.
  - Core number = APIC id / threads per core (read from the CPU) instead of assuming 2.
  - The file is saved as UTF-8 with BOM, so Windows PowerShell 5.1 reads the accented "SÍ" in the confirmation prompt correctly.

## 2026-10-30
- `loq-crash-signature.ps1` v1.1 (read-only check, S1–S6) and `loq-vmin-test.ps1` v1.0 (optional active test). Docs in English and Spanish, issue template.
