"""MercadoLibre Inmuebles — usa la URL con filtro /dueno-directo/ y lee las tarjetas del listado."""
from __future__ import annotations

from bs4 import BeautifulSoup

from common import (Aviso, descargar_seguro, pausa, texto, parse_precio, parse_m2,
                    parse_ambientes, parse_dormitorios, es_dueno_directo, limpiar_url)

NOMBRE = "MercadoLibre"
BASE = "https://inmuebles.mercadolibre.com.ar"
POR_PAGINA = 48


def url_pagina(tipo: str, operacion: str, zona_slug: str, pagina: int) -> str:
    url = f"{BASE}/{tipo}/{operacion}/{zona_slug}/dueno-directo/"
    if pagina > 1:
        url += f"_Desde_{(pagina - 1) * POR_PAGINA + 1}_NoIndex_True"
    return url


def _primero(card, selectores: list[str]):
    for sel in selectores:
        el = card.select_one(sel)
        if el:
            return el
    return None


def parsear(html: str, operacion: str, tipo: str, zona: str) -> list[Aviso]:
    soup = BeautifulSoup(html, "html.parser")
    tarjetas = soup.select("li.ui-search-layout__item") or soup.select("div.poly-card") \
        or soup.select("div.ui-search-result__wrapper")
    avisos: list[Aviso] = []
    for card in tarjetas:
        link = _primero(card, ["a.poly-component__title", "h3 a", "a.ui-search-link", "a[href*='MLA']"])
        if not link or not link.get("href"):
            continue
        url = limpiar_url(link["href"])
        titulo = texto(link.get_text()) or texto(card.get_text())[:90]

        precio_el = _primero(card, [".poly-price__current", ".andes-money-amount", ".ui-search-price__second-line"])
        precio, moneda = (None, None)
        if precio_el:
            precio, moneda = parse_precio(precio_el.get_text(" "))

        attrs = " · ".join(texto(li.get_text()) for li in card.select(
            ".poly-attributes_list li, .poly-attributes-list__item, .ui-search-card-attributes__attribute, "
            ".poly-component__attributes-list li"))
        todo = texto(card.get_text(" "))
        base_attr = attrs or todo

        ubic = _primero(card, [".poly-component__location", ".ui-search-item__location",
                               ".ui-search-item__group__element--location"])
        ubicacion = texto(ubic.get_text()) if ubic else ""
        img = card.select_one("img")
        imagen = ""
        if img:
            imagen = img.get("data-src") or img.get("src") or ""
            if imagen.startswith("data:"):
                imagen = ""

        vendedor = _primero(card, [".poly-component__seller", ".ui-search-official-store-label"])
        vend_txt = texto(vendedor.get_text()) if vendedor else ""

        partes = [p.strip() for p in ubicacion.split(",") if p.strip()]
        barrio = partes[-2] if len(partes) >= 2 else (partes[0] if partes else "")

        avisos.append(Aviso(
            fuente=NOMBRE, url=url, titulo=titulo, operacion=operacion, tipo=tipo, zona=zona,
            precio=precio, moneda=moneda, m2=parse_m2(base_attr), ambientes=parse_ambientes(base_attr + " " + titulo),
            dormitorios=parse_dormitorios(base_attr), barrio=barrio, direccion=ubicacion, imagen=imagen,
            dueno_directo=es_dueno_directo(titulo, vend_txt),
        ))
    return avisos


def buscar(config: dict, log) -> list[Aviso]:
    cfg = config["fuentes"]["mercadolibre"]
    resultado: list[Aviso] = []
    for op in config["operaciones"]:
        for tipo in config["tipos"]:
            for zona in config["zonas"]:
                for p in range(1, cfg["paginas"] + 1):
                    url = url_pagina(tipo, op, zona["mercadolibre"], p)
                    html = descargar_seguro(url, log)
                    pausa()
                    if not html:
                        break
                    encontrados = parsear(html, op, tipo, zona["nombre"])
                    log(f"  {NOMBRE} {op}/{tipo}/{zona['nombre']} p{p}: {len(encontrados)}")
                    resultado.extend(encontrados)
                    if len(encontrados) < 10:
                        break
    return resultado
