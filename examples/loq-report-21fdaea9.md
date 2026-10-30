# LOQ crash signature report (read-only check v1.1.0)

Generated 2026-10-30 | Event log window: 2026-09-26 to 2026-10-30 | Device id: `21fdaea9`

| Item | Value |
|---|---|
| model | LOQ 15ARP9 (83JC) |
| bios | PQCN31WW |
| cpu | AMD Ryzen 7 7435HS |
| cores | 8 cores / 16 threads |
| windows | 26H2 build 26300.9711 |
| ram | M425R1GB4PB0-CWMOD 8GB + M425R1GB4PB0-CWMOD 8GB |
| ram_ecc | no (DataWidth = TotalWidth) |
| processor_min_state | AC 80 % / DC 80 % |
| processor_max_state | AC 100 % / DC 100 % |

## Signatures found: 6 of 6
- **S1 MCA errors concentrated on one physical core: core 7 (100 % of 101 records), unit LS_V2 (core load-store / L1 data cache)**
- **S2 Windows shows these as "Memory" errors, but the RAM has no ECC and the reporting unit is a CPU core, not the memory controller**
- **S3 first boot fails after a cold start (8/9 cold vs 0/11 warm, p=7.14E-05)**
- **S4 crashes concentrated on battery (9 of 18 crashes in 8.2 % of powered-on time, p=3.97E-06)**
- **S5 most crashes inside Modern Standby (13 of 18)**
- **S6 1 app crash(es) with 0xC000001D (illegal instruction) inside Windows system DLLs**

## 1. WHEA hardware errors (S1, S2)
- WHEA events: 101 | WHEA 47 (shown as 'Memory' by Windows): 101 | decoded MCA records: 101

| Reporting unit (AMD SMCA) | Count |
|---|---|
| LS_V2 (core load-store / L1 data cache) | 101 |

| APIC id | Likely physical core (APIC/2) | Count |
|---|---|---|
| 14 | 7 | 98 |
| 15 | 7 | 3 |

- Corrected (CECC): 101 | Uncorrected: 0 | First: 2026-09-26 | Last: 2026-10-30

## 2. Unexpected shutdowns (S4, S5)
- Kernel-Power 41: 18 | Bugcheck codes: 0x0 x12, 0xA x3, 0x20001 x2, 0x1E x1
- Sessions that ended without a clean shutdown: 18 | power state at the last logged event: on AC 9, on battery 9, in Modern Standby 13
- Powered-on hours (approx.): AC 685.4 h, battery 61 h | crash rate AC 0.013/h, battery 0.148/h | p (battery concentration) = 3.97E-06

## 3. First boot after a clean shutdown (S3)
| Time off | Boots | First attempt failed |
|---|---|---|
| < 10 min (warm) | 11 | 0 |
| >= 60 min (cold) | 9 | 8 |
- Fisher exact test (one-sided) p = 7.14E-05

## 4. Illegal-instruction app crashes (S6)
- 0xC000001D crashes: 1 (inside system DLLs: 1) | modules: ntdll.dll x1

---
*Read-only check. S1+S2 point to one defective CPU core (on these laptops the APU is soldered: mainboard replacement), not to RAM. S3-S6 are patterns, not proof on their own. To confirm a low-voltage (Vmin) defect, run the optional `loq-vmin-test.ps1`. One report is one data point: please share yours.*
