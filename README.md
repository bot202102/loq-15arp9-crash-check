# LOQ 15ARP9 crash check — post-service audit branch

**Audit v2 · 2026-11-10 · Documentation and experimental acquisition, NOT a validated repair test.**

[Plan técnico en español](audit/v2/PLAN_TECNICO_Y_CRITERIOS.md) · [Audit index](audit/v2/README.md) · [Code findings](audit/v2/HALLAZGOS_REVISION_CODIGO.md) · [Local-agent handoff](audit/v2/PROMPT_CONTINUIDAD.md)

## Safety hold

Do **not** execute the historical `loq-vmin-test.ps1` v1.0.1. The audit identifies incomplete-run false negatives, insufficient AC-disconnect abort handling, unverified restoration and overly specific classification of unrelated errors. The `RUN-VMIN-TEST.cmd` launcher is intentionally disabled on this branch. The original PS1 is retained for review, not fixed or approved for direct execution.

The new `audit/v2/RECOLECCION_V2.ps1` is an **experimental** live logical acquisition script. Windows syntax and functional validation remain pending. No laptop test or repair certification is included in this branch.

## Start here

1. Read [AGENTS.md](AGENTS.md) and the [v2 index](audit/v2/README.md).
2. Preserve private evidence and validate tools before using them on the affected machine.
3. Follow the numbered plan and its acceptance gates. Separate preservation, topology, energy/update policies, historical error decoding and any later authorized active test.
4. Run the synthetic classifier examples with `python audit/v2/validar_logica.py`. This models Python conditions only; it does not validate PowerShell or hardware.

## Historical material

The baseline reviewed is commit `889e945f9fee1d6d6f57e938070280779c36460a`. Its [original README](https://github.com/bot202102/loq-15arp9-crash-check/blob/889e945f9fee1d6d6f57e938070280779c36460a/README.md), scripts and example report remain accessible in Git history. Historical summaries must be checked against original records; wording that equates a performance percentage with measured voltage or a no-error sample with a healthy board is superseded by the v2 protocol.

The public research distinguishes documented historical software incidents from unverified user accounts. It does not establish deliberate concealment of a damaged core in a warranty repair.

**Privacy:** do not upload corporate correspondence, case numbers, recovery keys, raw logs or dumps. Public source code can produce private output. This branch does not contain the private case dossier.

MIT License · No warranty · Not affiliated with Lenovo or AMD.
