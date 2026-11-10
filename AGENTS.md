# Working rules for this audit branch

Read `audit/v2/README.md`, `PLAN_TECNICO_Y_CRITERIOS.md`, `HALLAZGOS_REVISION_CODIGO.md` and `VALIDACION.md` in that directory before working on the laptop or changing diagnostic code.

## Scope and safety

- Preserve evidence before any modification. No BIOS/BCD, driver, update, power-plan, security or BitLocker changes without separate, explicit approval.
- Do NOT execute the historical `loq-vmin-test.ps1` v1.0.1, including Rehearsal or automatic report interpretation. Its false-negative, abort and restoration findings are unresolved. The CMD launcher is deliberately paused on this branch; the original PS1 remains solely for code review and historical comparison.
- `audit/v2/RECOLECCION_V2.ps1` is an experimental live logical acquisition script. It has NOT been functionally validated on Windows or run on the affected laptop. Syntax validation and a functional trial on a separate Windows system are required first.
- Do not treat a missing phase, unreadable event log, absent telemetry or failed restoration as zero errors. A valid negative observation is only `SIN_REPRODUCCION_EN_ESTA_CORRIDA`, not proof of repair.
- The Python scenarios model selected legacy classifier conditions. They do not run PowerShell, test hardware, validate the collector or implement a corrected active test.

## Privacy and evidence

This repository is public. Never commit corporate emails, service-case identifiers, personal identifiers, BitLocker recovery keys, raw EVTX/XML, memory dumps or full acquisition directories. Keep originals in private external storage. The .gitignore is not a security boundary; inspect all staged content.

Historical reports contain observations and hypotheses, not independent proof of a damaged microscopic component or deliberate concealment. Validate CPER/SMCA and topology, do not assume APIC/2 universally, and distinguish an energy-state change from measured voltage. Do not attribute user experiments to a technician without a chronology.

## Workflow

Use this branch, preserve the frozen historical commit referenced in the audit, and do not merge or write to main without approval. Record each phase's inputs, tool version/hash, output, limitations and next authorized action. Do not send email, contact third parties, publish evidence, install software or induce crashes merely because this branch exists.

Use `audit/v2/PROMPT_CONTINUIDAD.md` for the local handoff. Delegate public-source research only if a real subagent executor is available; never claim delegation that did not occur.
