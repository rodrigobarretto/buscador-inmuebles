"""Argenprop — intenta la URL con /dueno-directo; si no existe, recorre el listado general
y se queda solo con avisos que dicen explícitamente que son de dueño."""
from __future__ import annotations

from urllib.parse import urljoin

from bs4 import BeautifulSoup

from common import (Aviso, descargar_seguro, pausa, texto, parse_precio, parse_m2, numero,
                    parse_ambientes, parse_dormitorios, es_dueno_directo, limpiar_url, _DUENO)

NOMBRE = "Argenprop"
BASE = "https://www.argenprop.com"


def url_pagina(tipo: str, operacion: str, zona_slug: str, pagina: int, filtro_dueno: bool) -> str:
    url = f"{BASE}/{tipo}/{operacion}/{zona_slug}"
    if filtro_dueno:
        url += "/dueno-directo"
    if pagina > 1:
        url += f"?pagina-{pagina}"
    return url


def parsear(html: str, operacion: str, tipo: str, zona: str, estricto: bool) -> list[Aviso]:
    soup = BeautifulSoup(html, "html.parser")
    tarjetas = soup.select("div.listing__item") or soup.select("a.card")
    avisos: list[Aviso] = []
    for card in tarjetas:
        a = card if card.name == "a" else card.select_one("a.card, a[href]")
        if not a or not a.get("href"):
            continue
        url = limpiar_url(urljoin(BASE, a["href"]))

        def t(sel: str) -> str:
            el = card.select_one(sel)
            return texto(el.get_text(" ")) if el else ""

        titulo = t(".card__title--primary") or t(".card__title") or t("h2")
        direccion = t(".card__address")
        info = t(".card__info")
        feats = " · ".join(texto(li.get_text(" ")) for li in card.select(".card__main-features li, ul.card__main-features span"))
        todo = texto(card.get_text(" "))
        precio, moneda = parse_precio(t(".card__price") or "")
        exp_txt = t(".card__expenses")
        agente = t(".card__agent, .card__publisher, .card__real-estate")
        barrio = t(".card__title--location") or (direccion.split(",")[-1].strip() if "," in direccion else "")

        img = card.select_one("img")
        imagen = (img.get("data-src") or img.get("src") or "") if img else ""
        if imagen.startswith("data:"):
            imagen = ""

        dueno = es_dueno_directo(titulo, info, agente)
        if estricto:  # listado sin filtro: exigimos una señal explícita de dueño
            dueno = any(p in (titulo + " " + info).lower() for p in _DUENO) and not agente

        if not dueno:
            continue
        avisos.append(Aviso(
            fuente=NOMBRE, url=url, titulo=titulo or info[:90] or todo[:90], operacion=operacion, tipo=tipo,
            zona=zona, precio=precio, moneda=moneda, expensas=numero(exp_txt) if exp_txt else None,
            m2=parse_m2(feats or todo), ambientes=parse_ambientes(feats + " " + titulo),
            dormitorios=parse_dormitorios(feats), barrio=barrio, direccion=direccion, imagen=imagen,
            descripcion=info[:400], dueno_directo=True,
        ))
    return avisos


def buscar(config: dict, log) -> list[Aviso]:
    cfg = config["fuentes"]["argenprop"]
    resultado: list[Aviso] = []
    filtro_ok = True
    for op in config["operaciones"]:
        for tipo in config["tipos"]:
            for zona in config["zonas"]:
                for p in range(1, cfg["paginas"] + 1):
                    url = url_pagina(tipo, op, zona["argenprop"], p, filtro_ok)
                    html = descargar_seguro(url, log)
                    if html is None and filtro_ok and p == 1:
                        filtro_ok = False  # el portal no tiene esa URL: pasamos a modo estricto
                        log(f"  {NOMBRE}: sin URL de dueño directo, uso filtro por texto")
                        url = url_pagina(tipo, op, zona["argenprop"], p, False)
                        html = descargar_seguro(url, log)
                    pausa()
                    if not html:
                        break
                    encontrados = parsear(html, op, tipo, zona["nombre"], estricto=not filtro_ok)
                    log(f"  {NOMBRE} {op}/{tipo}/{zona['nombre']} p{p}: {len(encontrados)}")
                    resultado.extend(encontrados)
                    if "listing__item" not in html:
                        break
    return resultado
