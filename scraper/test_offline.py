"""Prueba sin internet: parsea HTML de muestra de cada portal y corre el puntaje.
Uso: python scraper/test_offline.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import parse_precio, parse_m2, parse_ambientes, es_dueno_directo  # noqa: E402
from fuentes import mercadolibre, argenprop, zonaprop  # noqa: E402
import puntaje  # noqa: E402


def tarjeta_ml(i, precio, m2, amb, barrio):
    p = f"{precio:,}".replace(",", ".")
    return f"""<li class="ui-search-layout__item"><div class="poly-card">
    <img src="https://http2.mlstatic.com/{i}.jpg">
    <div class="poly-price__current"><span class="andes-money-amount__currency-symbol">$</span>
    <span class="andes-money-amount__fraction">{p}</span></div>
    <ul class="poly-attributes_list"><li>{amb} ambientes</li><li>1 dormitorio</li><li>{m2} m² cubiertos</li></ul>
    <a class="poly-component__title" href="https://departamento.mercadolibre.com.ar/MLA-{i}-depto-_JM#pos">Departamento en alquiler {i}</a>
    <span class="poly-component__location">Av Siempreviva {i}, {barrio}, Capital Federal</span>
    </div></li>"""


def main():
    assert parse_precio("$ 650.000") == (650000, "ARS")
    assert parse_precio("USD 98.500") == (98500, "USD")
    assert parse_precio("Consultar precio") == (None, None)
    assert parse_m2("45 m² cubiertos") == 45
    assert parse_ambientes("Monoambiente luminoso") == 1
    assert parse_ambientes("3 amb.") == 3
    assert es_dueno_directo("Dueño alquila 2 amb") is True
    assert es_dueno_directo("Excelente depto", "Inmobiliaria Pérez, honorarios 1 mes") is False

    precios = [700000, 720000, 680000, 750000, 710000, 690000, 730000, 420000]
    html_ml = "<ul>" + "".join(tarjeta_ml(i, p, 40, 2, "Palermo") for i, p in enumerate(precios)) + "</ul>"
    ml = mercadolibre.parsear(html_ml, "alquiler", "departamentos", "CABA")
    assert len(ml) == 8, len(ml)
    assert ml[0].precio == 700000 and ml[0].moneda == "ARS" and ml[0].m2 == 40 and ml[0].ambientes == 2
    assert ml[0].barrio == "Palermo", ml[0].barrio
    assert "#" not in ml[0].url

    html_ap = """<div class="listing__item"><a class="card" href="/departamento-en-alquiler-en-palermo-2-ambientes--123">
      <p class="card__price">$ 700.000</p><span class="card__expenses">+ $ 90.000 expensas</span>
      <p class="card__address">Gorriti 4500, Palermo</p><p class="card__title">Dueño directo alquila 2 amb</p>
      <ul class="card__main-features"><li>40 m² cubie.</li><li>2 ambientes</li></ul>
      <img data-src="https://static.argenprop.com/x.jpg"></a></div>
      <div class="listing__item"><a class="card" href="/otro--124"><p class="card__price">$ 650.000</p>
      <p class="card__title">Lindo depto</p><p class="card__info">Inmobiliaria XX, honorarios</p></a></div>"""
    ap = argenprop.parsear(html_ap, "alquiler", "departamentos", "CABA", estricto=False)
    assert len(ap) == 1 and ap[0].expensas == 90000 and ap[0].url.startswith("https://www.argenprop.com/"), ap

    html_zp = """<div data-qa="posting PROPERTY" data-to-posting="/propiedades/clasificado/alclappa-dueno-alquila-2-amb-99.html">
      <div data-qa="POSTING_CARD_PRICE">$ 705.000</div><div data-qa="expensas">$ 80.000 Expensas</div>
      <div data-qa="POSTING_CARD_LOCATION">Palermo, Capital Federal</div>
      <div data-qa="POSTING_CARD_FEATURES">40 m² tot. 2 amb. 1 dorm.</div>
      <h3 data-qa="POSTING_CARD_DESCRIPTION">Dueño alquila 2 amb al frente</h3></div>"""
    zp = zonaprop.parsear(html_zp, "alquiler", "departamentos", "CABA")
    assert len(zp) == 1 and zp[0].precio == 705000 and zp[0].barrio == "Palermo", zp

    # El mismo depto en ML (700.000, 40 m², 2 amb, Palermo) y Argenprop debe fusionarse
    todos = puntaje.deduplicar(ml + ap + zp)
    assert len(todos) == 9, len(todos)
    puntaje.puntuar(todos)
    todos.sort(key=lambda a: a.puntaje, reverse=True)
    mejor = todos[0]
    assert mejor.precio == 420000, (mejor.precio, mejor.puntaje)
    print("Mejor:", mejor.precio, mejor.puntaje, mejor.motivos)
    fusionado = [a for a in todos if any("también" in m for m in a.motivos)]
    print("Fusionado:", [(a.fuente, a.motivos) for a in fusionado])
    assert fusionado
    print("OK - todas las pruebas pasaron")


if __name__ == "__main__":
    main()
