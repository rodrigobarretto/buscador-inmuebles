"""Puntaje de oportunidad (0-100).

Idea central: un aviso es buena oportunidad si cuesta bastante menos que propiedades
comparables (misma operación, moneda y barrio/zona), medido por m² cuando hay superficie
y por ambiente cuando no. Suma puntos por estar en varios portales, por ser nuevo y por
tener datos completos; penaliza precios absurdamente bajos (suelen ser errores o estafas).
"""
from __future__ import annotations

import re
import statistics
from collections import defaultdict

from common import Aviso, sin_acentos


def _clave_barrio(a: Aviso) -> str:
    return sin_acentos(a.barrio.lower()).strip() or "?"


def _metrica(a: Aviso):
    if not a.precio or not a.moneda:
        return None, None
    if a.m2:
        return "m2", a.precio / a.m2
    if a.ambientes:
        return f"amb{min(a.ambientes, 5)}", a.precio
    return None, None


def _medianas(avisos: list[Aviso]) -> dict:
    grupos: dict[tuple, list[float]] = defaultdict(list)
    for a in avisos:
        tipo_m, v = _metrica(a)
        if v is None:
            continue
        for nivel, ambito in (("barrio", _clave_barrio(a)), ("zona", a.zona), ("todo", "*")):
            grupos[(nivel, a.operacion, a.moneda, tipo_m, ambito)].append(v)
    return {k: (statistics.median(v), len(v)) for k, v in grupos.items() if len(v) >= 4}


def _referencia(a: Aviso, med: dict):
    tipo_m, v = _metrica(a)
    if v is None:
        return None
    for nivel, ambito, etiqueta in (("barrio", _clave_barrio(a), a.barrio or a.zona),
                                    ("zona", a.zona, a.zona), ("todo", "*", "el total")):
        k = (nivel, a.operacion, a.moneda, tipo_m, ambito)
        if k in med and med[k][1] >= (6 if nivel == "barrio" else 4):
            return v, med[k][0], etiqueta, tipo_m
    return None


def _firma(a: Aviso) -> str:
    """Huella para detectar la misma propiedad publicada en varios portales."""
    p = int(a.precio // 1000) if a.precio else 0
    m = int(a.m2 or 0)
    b = re.sub(r"[^a-z]", "", sin_acentos(a.barrio.lower()))[:10]
    return f"{a.operacion}|{a.moneda}|{p}|{m}|{a.ambientes}|{b}"


def deduplicar(avisos: list[Aviso]) -> list[Aviso]:
    por_url: dict[str, Aviso] = {}
    for a in avisos:
        por_url.setdefault(a.id, a)
    unicos = list(por_url.values())
    por_firma: dict[str, list[Aviso]] = defaultdict(list)
    for a in unicos:
        if a.precio and (a.m2 or a.ambientes) and a.barrio:
            por_firma[_firma(a)].append(a)
    descartar = set()
    for grupo in por_firma.values():
        fuentes = {a.fuente for a in grupo}
        if len(fuentes) > 1:
            principal = max(grupo, key=lambda x: (bool(x.imagen), bool(x.m2), len(x.descripcion)))
            otras = sorted(fuentes - {principal.fuente})
            principal.motivos.append(f"Publicado también en {', '.join(otras)}")
            for a in grupo:
                if a is not principal:
                    descartar.add(a.id)
    return [a for a in unicos if a.id not in descartar]


def puntuar(avisos: list[Aviso]) -> dict:
    med = _medianas(avisos)
    for a in avisos:
        puntos = 40.0
        ref = _referencia(a, med)
        if ref:
            valor, mediana, etiqueta, tipo_m = ref
            ratio = valor / mediana if mediana else 1
            if ratio < 0.35:
                puntos = 25
                a.motivos.append("Precio sospechosamente bajo: revisá que no sea error o estafa")
            else:
                puntos = max(0.0, min(100.0, 60 - (ratio - 1) * 100))
                diff = round((1 - ratio) * 100)
                unidad = "por m²" if tipo_m == "m2" else "para esa cantidad de ambientes"
                if diff >= 5:
                    a.motivos.append(f"{diff}% más barato que la mediana de {etiqueta} {unidad}")
                elif diff <= -5:
                    a.motivos.append(f"{-diff}% más caro que la mediana de {etiqueta} {unidad}")
        elif not a.precio:
            puntos = 20
            a.motivos.append("Sin precio publicado")
        if any(m.startswith("Publicado también") for m in a.motivos):
            puntos += 6
        if a.nuevo:
            puntos += 5
        if a.m2 and a.ambientes and a.imagen:
            puntos += 4
        if a.expensas is not None and a.precio and a.moneda == "ARS" and a.operacion == "alquiler":
            if a.expensas > a.precio * 0.45:
                puntos -= 8
                a.motivos.append("Expensas muy altas respecto del alquiler")
        a.puntaje = round(max(0.0, min(100.0, puntos)), 1)
    return {"/".join(map(str, k)): round(v[0]) for k, v in med.items() if k[0] != "barrio"}
