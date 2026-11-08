"""Aviso diario al celular vía ntfy.sh (gratis, sin cuenta ni tarjeta)."""
from __future__ import annotations

import os

import requests


def _precio(a: dict) -> str:
    if not a.get("precio"):
        return "consultar"
    simbolo = "US$" if a.get("moneda") == "USD" else "$"
    return f"{simbolo} {int(a['precio']):,}".replace(",", ".")


def enviar(oportunidades: list[dict], top: int, minimo: float, log) -> None:
    topic = os.environ.get("NTFY_TOPIC", "").strip()
    if not topic:
        log("Sin NTFY_TOPIC configurado: no envío notificación")
        return
    nuevos = [a for a in oportunidades if a.get("nuevo") and a.get("dueno_directo") and a["puntaje"] >= minimo]
    if not nuevos:
        log("No hay oportunidades nuevas por encima del puntaje mínimo")
        return
    lineas = []
    for a in nuevos[:top]:
        op = "Alq" if a["operacion"] == "alquiler" else "Vta"
        amb = f"{a['ambientes']} amb · " if a.get("ambientes") else ""
        m2 = f"{int(a['m2'])} m² · " if a.get("m2") else ""
        lineas.append(f"⭐{int(a['puntaje'])} {op} {_precio(a)} · {amb}{m2}{a.get('barrio') or a['zona']}")
    cuerpo = "\n".join(lineas)
    if len(nuevos) > top:
        cuerpo += f"\n… y {len(nuevos) - top} más en la app"
    try:
        r = requests.post("https://ntfy.sh/", json={
            "topic": topic,
            "title": f"🏠 {len(nuevos)} oportunidades nuevas de dueño directo",
            "message": cuerpo,
            "tags": ["house"],
            "click": nuevos[0]["url"],
            "priority": 4 if nuevos[0]["puntaje"] >= 80 else 3,
        }, timeout=20)
        log(f"Notificación enviada ({r.status_code})")
    except Exception as e:
        log(f"No se pudo notificar: {e}")
