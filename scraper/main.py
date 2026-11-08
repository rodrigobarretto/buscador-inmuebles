"""Buscador diario de oportunidades inmobiliarias de dueño directo.

Uso:  python scraper/main.py            (corre todas las fuentes activas)
      python scraper/main.py --rapido   (1 página por fuente, para probar)
Escribe data/oportunidades.json y data/historial.json.
"""
from __future__ import annotations

import json
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))

import common  # noqa: E402
import notificar  # noqa: E402
import puntaje  # noqa: E402
from fuentes import argenprop, mercadolibre, zonaprop  # noqa: E402

RAIZ = AQUI.parent
DATA = RAIZ / "data"
FUENTES = {"mercadolibre": mercadolibre, "argenprop": argenprop, "zonaprop": zonaprop}
ART = timezone(timedelta(hours=-3))
# Avisos que no son vivienda aunque aparezcan en la categoría departamentos/casas
NO_VIVIENDA = re.compile(r"\b(oficina|consultorio|local comercial|cochera|galp[oó]n|dep[oó]sito|terreno|lote)\b", re.I)


def log(msg: str) -> None:
    print(msg, flush=True)


def cargar_json(ruta: Path, defecto):
    try:
        return json.loads(ruta.read_text(encoding="utf-8"))
    except Exception:
        return defecto


def main() -> None:
    config = json.loads((AQUI / "config.json").read_text(encoding="utf-8"))
    if "--rapido" in sys.argv:
        for f in config["fuentes"].values():
            f["paginas"] = 1
    common.PAUSA = tuple(config.get("pausa_segundos", [2.0, 4.5]))

    ahora = datetime.now(ART)
    hoy = ahora.date().isoformat()
    DATA.mkdir(exist_ok=True)

    todos: list[common.Aviso] = []
    estado: dict[str, dict] = {}
    for nombre, modulo in FUENTES.items():
        if not config["fuentes"].get(nombre, {}).get("activa"):
            continue
        log(f"▶ {modulo.NOMBRE}")
        t0 = time.time()
        try:
            encontrados = modulo.buscar(config, log)
            estado[modulo.NOMBRE] = {"ok": bool(encontrados), "cantidad": len(encontrados),
                                     "error": "" if encontrados else "Sin resultados (¿bloqueo o cambió el sitio?)"}
            todos.extend(encontrados)
        except Exception as e:  # una fuente rota nunca frena a las demás
            estado[modulo.NOMBRE] = {"ok": False, "cantidad": 0, "error": str(e)[:200]}
            log(f"  ✖ {modulo.NOMBRE}: {e}")
        estado[modulo.NOMBRE]["segundos"] = round(time.time() - t0)

    log(f"Total crudo: {len(todos)}")
    todos = [a for a in todos if a.dueno_directo and not NO_VIVIENDA.search(a.titulo)]
    todos = puntaje.deduplicar(todos)
    log(f"Dueño directo y sin duplicados: {len(todos)}")

    # Historial: fecha en que vimos cada aviso por primera vez → marca "nuevo"
    hist_path = DATA / "historial.json"
    historial: dict[str, str] = cargar_json(hist_path, {})
    for a in todos:
        a.primera_vez = historial.get(a.id, hoy)
        a.nuevo = a.primera_vez == hoy
        historial.setdefault(a.id, hoy)
    limite = (ahora.date() - timedelta(days=config.get("dias_historial", 30) * 3)).isoformat()
    historial = {k: v for k, v in historial.items() if v >= limite}

    medianas = puntaje.puntuar(todos)
    todos.sort(key=lambda a: (a.puntaje, a.nuevo), reverse=True)
    todos = todos[: config.get("max_resultados", 1500)]

    # Si hoy todas las fuentes fallaron, no pisamos los datos de ayer
    if not todos:
        log("Sin resultados hoy: conservo el archivo anterior")
        previo = cargar_json(DATA / "oportunidades.json", {})
        previo["ultimo_intento"] = ahora.isoformat()
        previo["estado_fuentes"] = estado
        (DATA / "oportunidades.json").write_text(json.dumps(previo, ensure_ascii=False, indent=1), encoding="utf-8")
        return

    salida = {
        "generado": ahora.isoformat(),
        "ultimo_intento": ahora.isoformat(),
        "total": len(todos),
        "nuevos": sum(a.nuevo for a in todos),
        "estado_fuentes": estado,
        "medianas": medianas,
        "avisos": [a.dict() for a in todos],
    }
    (DATA / "oportunidades.json").write_text(json.dumps(salida, ensure_ascii=False, indent=1), encoding="utf-8")
    hist_path.write_text(json.dumps(historial, ensure_ascii=False), encoding="utf-8")
    log(f"✔ Guardadas {len(todos)} oportunidades ({salida['nuevos']} nuevas)")

    notificar.enviar(salida["avisos"], config.get("aviso_top", 8), config.get("puntaje_minimo_aviso", 60), log)


if __name__ == "__main__":
    main()
