"""Casos sinteticos de las ramas del clasificador v1.0.1.
NO ejecuta PowerShell, no accede a Windows y no prueba el hardware.
"""
from __future__ import annotations
import json
from pathlib import Path


def rama_legacy(d: dict) -> str:
    """Transcripcion de las condiciones de Write-Report, no del script completo."""
    a0, b, a1 = (int(d.get(k) or 0) for k in ("A0", "B", "A1"))
    if d.get("read_error"):
        return "INCONCLUSIVE"
    if d.get("rehearsal"):
        return "REHEARSAL"
    if b > 0 and a0 == 0 and a1 == 0:
        return "POSITIVE"
    if d.get("crashed") and d.get("crash_phase") == "B" and a0 == 0:
        return "POSITIVE_CRASH"
    if b == 0 and not d.get("crashed"):
        return "NEGATIVE"
    return "INCONCLUSIVE"


def main() -> None:
    cases = [
        ("Abortada antes de B por cap no verificado", {"A0": 0, "finished": False}, "NEGATIVE", "INCONCLUSO_ABORTADO"),
        ("B interrumpida prematuramente sin eventos", {"A0": 0, "B": 0, "finished": False}, "NEGATIVE", "INCONCLUSO_DURACION"),
        ("WHEA PCIe en B, no CPU historico", {"A0": 0, "B": 1, "A1": 0, "source": "PCIe", "finished": True}, "POSITIVE", "OTRO_ERROR"),
        ("Error B con A1 ausente", {"A0": 0, "B": 1, "finished": False}, "POSITIVE", "ERROR_OBSERVADO_SIN_RECUPERACION_DEMOSTRADA"),
        ("Cuelgue B sin CPER concordante", {"A0": 0, "B": 0, "crashed": True, "crash_phase": "B"}, "POSITIVE_CRASH", "CUELGUE_ASOCIADO"),
        ("Corrida valida sin errores", {"A0": 0, "B": 0, "A1": 0, "finished": True}, "NEGATIVE", "SIN_REPRODUCCION_EN_ESTA_CORRIDA"),
        ("Error al leer eventos", {"A0": 0, "B": 0, "read_error": True}, "INCONCLUSIVE", "INCONCLUSO_LECTURA"),
        ("Errores basales, sin errores B", {"A0": 1, "B": 0, "A1": 0, "finished": True}, "NEGATIVE", "ERRORES_OBSERVADOS_FUERA_DE_B"),
    ]
    rows = []
    for name, data, expected_old, required in cases:
        actual = rama_legacy(data)
        assert actual == expected_old, (name, actual, expected_old)
        rows.append({"scenario": name, "synthetic_input": data, "legacy_branch": actual, "required_protocol_interpretation": required})
    result = {
        "scope": "Transcripcion logica Python con entradas sinteticas; NO ejecucion de PowerShell ni hardware",
        "source_commit": "889e945f9fee1d6d6f57e938070280779c36460a",
        "cases_checked": len(rows),
        "rows": rows,
    }
    dest = Path(__file__).with_name("PRUEBAS_LOGICAS.json")
    dest.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(rows)} escenarios sinteticos comprobados. {dest.name}")


if __name__ == "__main__":
    main()
