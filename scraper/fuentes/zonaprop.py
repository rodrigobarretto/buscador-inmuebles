"""Zonaprop — URL con sufijo -dueno-directo. Es la fuente con más protección anti-bot:
si nos bloquea, el buscador registra el aviso en el log y sigue con las demás."""
from __future__ import annotations

from urllib.parse import urljoin

from bs4 import BeautifulSoup

from common import (Aviso, descargar, pausa, texto, parse_precio, parse_m2, numero,
                    parse_ambientes, parse_dormitorios, es_dueno_directo, limpiar_url, Bloqueado)

NOMBRE = "Zonaprop"
BASE = "https://www.zonaprop.com.ar"


def url_pagina(tipo: str, operacion: str, zona_slug: str, pagina: int) -> str:
    sufijo = f"-pagina-{pagina}" if pagina > 1 else ""
    return f"{BASE}/{tipo}-{operacion}-{zona_slug}-dueno-directo{sufijo}.html"


def parsear(html: str, operacion: str, tipo: str, zona: str) -> list[Aviso]:
    soup = BeautifulSoup(html, "html.parser")
    tarjetas = soup.select("[data-to-posting]") or soup.select('[data-qa^="posting"]')
    avisos: list[Aviso] = []
    vistos = set()
    for card in tarjetas:
        href = card.get("data-to-posting")
        if not href:
            a = card.select_one("a[href*='/propiedades/']")
            href = a.get("href") if a else None
        if not href:
            continue
        url = limpiar_url(urljoin(BASE, href))
        if url in vistos:
            continue
        vistos.add(url)

        def qa(nombre: str) -> str:
            el = card.select_one(f'[data-qa="{nombre}"]')
            return texto(el.get_text(" ")) if el else ""

        precio, moneda = parse_precio(qa("POSTING_CARD_PRICE"))
        exp = qa("expensas")
        ubic = qa("POSTING_CARD_LOCATION")
        direccion = qa("POSTING_CARD_ADDRESS") or texto((card.select_one(".postingAddress") or card).get_text(" "))[:80]
        feats = qa("POSTING_CARD_FEATURES")
        desc = qa("POSTING_CARD_DESCRIPTION")
        titulo_el = card.select_one("h2, h3, [data-qa='POSTING_CARD_TITLE']")
        titulo = texto(titulo_el.get_text(" ")) if titulo_el else (desc[:90] or direccion)
        img = card.select_one("img")
        imagen = (img.get("data-src") or img.get("src") or "") if img else ""
        if imagen.startswith("data:"):
            imagen = ""
        logo = card.select_one('[data-qa="POSTING_CARD_PUBLISHER"] img, img[alt*="logo"]')
        publicador = logo.get("alt", "") if logo else ""

        avisos.append(Aviso(
            fuente=NOMBRE, url=url, titulo=titulo, operacion=operacion, tipo=tipo, zona=zona,
            precio=precio, moneda=moneda, expensas=numero(exp) if exp else None, m2=parse_m2(feats),
            ambientes=parse_ambientes(feats + " " + titulo), dormitorios=parse_dormitorios(feats),
            barrio=ubic.split(",")[0].strip() if ubic else "", direccion=direccion, imagen=imagen,
            descripcion=desc[:400], dueno_directo=es_dueno_directo(titulo, desc, publicador),
        ))
    return avisos


def buscar(config: dict, log) -> list[Aviso]:
    cfg = config["fuentes"]["zonaprop"]
    resultado: list[Aviso] = []
    bloqueos = 0
    for op in config["operaciones"]:
        for tipo in config["tipos"]:
            for zona in config["zonas"]:
                for p in range(1, cfg["paginas"] + 1):
                    url = url_pagina(tipo, op, zona["zonaprop"], p)
                    try:
                        html = descargar(url)
                    except Bloqueado as e:
                        bloqueos += 1
                        log(f"  {NOMBRE}: bloqueado ({e})")
                        if bloqueos >= 3:
                            log(f"  {NOMBRE}: 3 bloqueos seguidos, salteo la fuente hoy")
                            return resultado
                        break
                    pausa()
                    if not html:
                        break
                    bloqueos = 0
                    encontrados = parsear(html, op, tipo, zona["nombre"])
                    log(f"  {NOMBRE} {op}/{tipo}/{zona['nombre']} p{p}: {len(encontrados)}")
                    resultado.extend(encontrados)
                    if len(encontrados) < 10:
                        break
    return resultado
