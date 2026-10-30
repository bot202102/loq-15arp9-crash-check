# LOQ 15ARP9 crash check — weak CPU core at low voltage

*Versión en español: [README.es.md](README.es.md)*

Does your **Lenovo LOQ 15ARP9** (or another laptop with a Ryzen 7035-series CPU) do any of this?

- freezes or reboots **in sleep / Modern Standby**,
- fails the **first boot after being off for hours** (Automatic Repair, black screen), but boots fine on the second try,
- crashes **soon after you unplug the charger**, or when **battery saver kicks in at 30 %**,
- shows **"Corrected hardware error — Component: Memory" (WHEA-Logger 47)** in Event Viewer, although memory tests pass.

On our unit all of that came from **one CPU core whose L1 data cache fails at low voltage**, which is a hardware defect. Windows mislabels it as a RAM problem. We could switch the errors on and off at will, which is the test included here.

**We need your data** to find out whether this is a batch/design problem or a few bad units. It takes 1 minute (read-only check) or about 23 minutes (optional active test).

---

## 1. Read-only check (1 minute, changes nothing)

1. Download this repository (**Code → Download ZIP**) and unzip it.
2. Double-click **`RUN-CHECK.cmd`**. No admin rights needed.
3. A file `loq-report-xxxxxxxx.md` appears. **[Open an issue](../../issues/new/choose)** and paste it.

What it looks for:

| Code | Signature | What it means |
|---|---|---|
| **S1** | WHEA 47 records, decoded from the raw machine-check data, ≥80 % from **one physical core** and from a core unit (LS / IF / L2 …) | One defective CPU core. **It can be any core**: the report tells you which one |
| **S2** | Windows says "Memory", but your RAM has no ECC and the reporting unit is not the memory controller | It is **not** your RAM. Replacing RAM won't help |
| **S3** | First boot after a clean shutdown fails far more often after >60 min off than after <10 min | Cold-start failure |
| **S4** | Crashes concentrated on battery, relative to time on battery | Low-voltage operating point on battery |
| **S5** | Most crashes inside Modern Standby | Deep idle at low voltage |
| **S6** | Apps crashing with `0xC000001D` (illegal instruction) inside Windows system DLLs | The CPU read corrupted instructions |

It also prints the **minimum processor state** of your power plan. If it says something like `AC 80 % / DC 5 %`, that explains why the laptop can be stable while plugged in and crash on battery.

## 2. Optional active test (about 23 minutes, may crash the PC)

`RUN-VMIN-TEST.cmd` runs three phases while plugged in:

| Phase | Duration | CPU state | Expected on an affected unit |
|---|---|---|---|
| A0 | 3 min | your normal settings | 0 errors |
| B | up to 15 min | **lowest performance state = lowest voltage** | WHEA 47 errors from one core (ours: after ~5 min) |
| A1 | 5 min | normal settings again | errors stop |

A light load runs on **every** logical CPU, so whichever core is weak shows up. The script decodes each new error as it arrives and writes `vmin-report-….md`.

**Before you run it:** save your work, close everything, keep the charger connected, and **don't close the lid**. If your disk uses BitLocker, have the recovery key at hand (on your phone, or at https://aka.ms/myrecoverykey), because repeated crashes can make Windows ask for it.

**If it crashes:** let it reboot, log in, and run `loq-vmin-test.ps1 -Report`. It reads the interrupted run and writes the report. A crash in phase B is also a result.

To check the mechanics first, with no low voltage: `loq-vmin-test.ps1 -Rehearsal` (3 × 1 min with a harmless 90 % cap).

### Why your PC won't come back in a crash loop

The obvious design (save the low setting, restore it after reboot) is unsafe. Windows' power service applies the saved plan very early in boot, **before** any restore task or logon script can run. So this test never saves the low setting:

1. it writes the test values and activates them;
2. **immediately** writes your original values back to the registry, *without* activating them. Microsoft documents that changes to the active plan "do not take effect until you call PowerSetActiveScheme";
3. checks both things before continuing: the registry holds your values, and the cap is really active.

The CPU keeps the cap in memory while the registry already holds your normal values. If the PC crashes, the cap is gone, and Windows boots with your normal settings from the first instant. The test values sit in the registry for ~0.1–0.2 s (logged in the report). The script refuses to run on battery, ends phase B after 3 errors, and stops if you unplug the charger.

## 3. Send your feedback (please do, even if nothing was found)

**[Open an issue](../../issues/new/choose)** with your report(s). Tell us:

- your model, BIOS version and how old the laptop is;
- what symptoms you have (or "none", which also helps);
- if you ran the active test: did errors appear, after how many minutes, on which core, and did it crash?
- anything that was unclear or didn't work. If the script failed, paste the console output.

**Negative results are just as valuable as positive ones.** Only many reports can tell a design problem from a few bad units.

## Reference case (#1)

LOQ 15ARP9 · 83JC · Ryzen 7 7435HS · BIOS PQCN31WW (latest at the time) · 2 × 8 GB Samsung DDR5 (non-ECC). Problems started ~10 months after purchase and got worse every week.

- **Read-only check: 6 of 6 signatures.** 101 WHEA records, all from **LS_V2 (L1 data cache) of physical core 7** (APIC 14/15). 8 of 9 cold boots failed vs 0 of 11 warm (p = 7×10⁻⁵). 9 of 18 crashes happened on battery in 8 % of the time (p = 4×10⁻⁶). [Full report](examples/loq-report-21fdaea9.md). Of those 101 records, 31 came from the active test below. The `DC 80 %` minimum in that report was a temporary experiment.
- **Active test** (run with this script's predecessor, same in-memory mechanism):

  | Phase | Duration | WHEA 47 | Core |
  |---|---|---|---|
  | Normal (plugged in, AC minimum 80 %) | 156 h | **0** | — |
  | **Lowest voltage** | 15.7 min | **31** (first after 5.5 min) | **31/31 on APIC 14 = core 7** |
  | Normal again | 7.8 min | **0** | — |

- **Battery runs:** two runs from 79.5 % crashed **56 and 74 s after the battery crossed 30 %**, the moment Windows Energy Saver lowers CPU performance. One crash left a `0x20001 HYPERVISOR_ERROR` dump; 85 s before it, an app crashed with `0xC000001D` inside `ntdll.dll`.
- Raising the battery minimum processor state to 80 % made the laptop last longer on battery (56 → 91 min) but did not stop the crashes.

## Known public reports of the same model (not decoded yet)

- r/LenovoLOQ — [*LOQ 15ARP9 boot loops / Automatic Repair, but works perfectly once it boots*](https://www.reddit.com/r/LenovoLOQ/comments/1wvyrv0/loq_15arp9_boot_loops_automatic_repair_but_works/): cold-boot failures, occasional restarts on battery, Kernel-Power 41 with bugcheck 0 and no dump, on PQCN31WW.
- r/LenovoLOQ — [*LOQ 15ARP9 suddenly restarts/crashes immediately when unplugged from AC*](https://www.reddit.com/r/LenovoLOQ/comments/1vlhd20/loq_15arp9_suddenly_restartscrashes_immediately/): restarts on unplugging, and once when switching Lenovo Vantage from Performance to Quiet. That is another drop to a lower power state.
- r/Lenovo — [*Lenovo LOQ 15ARP9 nightmare*](https://www.reddit.com/r/Lenovo/comments/1up5odx/lenovo_loq_15arp9_nightmare/): freezes at idle and in sleep. The author says two motherboard replacements did not help, and a July BIOS update fixed the sleep freezes. **This may contradict our hypothesis, or show that firmware can mask it.** On our unit, the latest BIOS did not help.

If you are one of them, the decoded data is what nobody has posted yet.

## FAQ

**Is it always core 7?** No. Core 7 is what *our* unit shows. The tools report whichever core produces the errors, and it may be several. If many units turned out to show the same core, that would itself be an important finding.

**My check shows 0 WHEA errors but I do get crashes.** WHEA only logs errors the CPU *corrected*. An uncorrected error crashes the PC before anything is logged. Run the active test.

**Can the test damage my CPU?** It doesn't overclock or overvolt anything. It holds the CPU in its own normal lowest performance state, the same one used on battery and at idle. The risk is a crash, which means losing unsaved work.

**Will a BIOS update fix it?** On our unit, updating to the latest BIOS (PQCN31WW) changed nothing.

**Does it work on Intel or other brands?** The checks run on any Windows laptop, but decoding *which core* failed is implemented for AMD (SMCA) only.

**Will the RAM or a new battery fix it?** Not if you have S1 + S2: the errors come from a CPU core. On these laptops the CPU is soldered, so the warranty repair is a mainboard replacement.

**Anything I can do meanwhile?** In our tests, crashes on battery came later with a higher minimum processor state, but they did not stop. Keep it plugged in for important work, and keep your data backed up.

## Privacy

Reports contain model, BIOS, CPU, Windows build, RAM part numbers and statistics. **No serial number, user name or file paths.** The device id is the first 8 hex characters of SHA-256(serial + this PC's random `MachineGuid`). It stays the same across runs, so duplicates can be spotted, but it cannot be turned back into your serial number. Read both scripts before running them; they are plain PowerShell.

## Limits

- The check reads the Windows event log, which usually covers only the last 4–8 weeks.
- The power-state reconstruction (AC / battery / standby at the time of a crash) is approximate.
- One report is one data point.

MIT License · No warranty · Not affiliated with Lenovo or AMD.
