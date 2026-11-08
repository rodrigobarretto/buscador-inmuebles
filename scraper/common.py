"""Herramientas compartidas por todas las fuentes: descarga, modelo de aviso y parseo de textos."""
from __future__ import annotations

import hashlib
import json
import random
import re
import time
import unicodedata
from dataclasses import dataclass, field, asdict
from typing import Iterable, Optional

try:  # curl_cffi imita la huella TLS de Chrome: pasa mejor las protecciones anti-bot
    from curl_cffi import requests as cffi_requests  # type: ignore
except Exception:  # pragma: no cover
    cffi_requests = None

import requests

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
)
HEADERS = {
    "User-Agent": UA,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "es-AR,es;q=0.9,en;q=0.6",
}

PAUSA = (2.0, 4.5)


def pausa() -> None:
    time.sleep(random.uniform(*PAUSA))


class Bloqueado(Exception):
    """La fuente respondió con un bloqueo (403, captcha, Cloudflare)."""


def descargar(url: str, intentos: int = 2) -> Optional[str]:
    """Devuelve el HTML o None si la página no existe. Lanza Bloqueado si la fuente nos frena."""
    ultimo_error = None
    for i in range(intentos):
        try:
            if cffi_requests is not None:
                r = cffi_requests.get(url, headers=HEADERS, impersonate="chrome", timeout=30)
            else:
                r = requests.get(url, headers=HEADERS, timeout=30)
            if r.status_code == 404:
                return None
            if r.status_code in (403, 429, 503):
                ultimo_error = Bloqueado(f"HTTP {r.status_code} en {url}")
            else:
                html = r.text
                bajo = html[:4000].lower()
                if "cf-challenge" in bajo or "just a moment" in bajo or "captcha" in bajo:
                    ultimo_error = Bloqueado(f"Desafío anti-bot en {url}")
                else:
                    return html
        except Bloqueado as e:
            ultimo_error = e
        except Exception as e:  # red, timeout
            ultimo_error = e
        time.sleep(3 + 4 * i)
    if isinstance(ultimo_error, Bloqueado):
        raise ultimo_error
    raise RuntimeError(str(ultimo_error))


def descargar_seguro(url: str, log) -> Optional[str]:
    """Como descargar(), pero si la fuente bloquea o falla devuelve None y lo deja en el log."""
    try:
        return descargar(url)
    except Exception as e:
        log(f"  ! {e}")
        return None


@dataclass
class Aviso:
    fuente: str
    url: str
    titulo: str
    operacion: str              # alquiler | venta
    tipo: str                   # departamentos | casas | ph
    zona: str                   # CABA, GBA Norte...
    precio: Optional[float] = None
    moneda: Optional[str] = None  # ARS | USD
    expensas: Optional[float] = None
    m2: Optional[float] = None
    ambientes: Optional[int] = None
    dormitorios: Optional[int] = None
    barrio: str = ""
    direccion: str = ""
    imagen: str = ""
    descripcion: str = ""
    dueno_directo: bool = True
    vistas: Optional[int] = None
    publicado: str = ""
    id: str = ""
    puntaje: float = 0.0
    motivos: list = field(default_factory=list)
    primera_vez: str = ""
    nuevo: bool = False

    def __post_init__(self) -> None:
        if not self.id:
            base = limpiar_url(self.url)
            self.id = hashlib.sha1(base.encode()).hexdigest()[:14]

    def dict(self) -> dict:
        return asdict(self)


def limpiar_url(url: str) -> str:
    return url.split("#")[0].split("?")[0].rstrip("/")


def sin_acentos(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


def texto(s: Optional[str]) -> str:
    return re.sub(r"\s+", " ", s or "").strip()


_NUM = re.compile(r"(\d{1,3}(?:[.\s]\d{3})+|\d+)(?:,(\d+))?")


def numero(s: str) -> Optional[float]:
    """'1.250.000' -> 1250000 ; '45,5' -> 45.5"""
    if not s:
        return None
    m = _NUM.search(s)
    if not m:
        return None
    entero = re.sub(r"[.\s]", "", m.group(1))
    try:
        return float(f"{entero}.{m.group(2)}" if m.group(2) else entero)
    except ValueError:
        return None


def parse_precio(s: str) -> tuple[Optional[float], Optional[str]]:
    if not s:
        return None, None
    s = texto(s)
    bajo = s.lower()
    if "consultar" in bajo:
        return None, None
    moneda = None
    if "us$" in bajo or "usd" in bajo or "u$s" in bajo or "dólar" in bajo or "dolar" in bajo:
        moneda = "USD"
    elif "$" in s or "ars" in bajo:
        moneda = "ARS"
    return numero(s), moneda


def parse_m2(s: str) -> Optional[float]:
    s = sin_acentos((s or "").lower())
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*(?:m2|m²|mts|metros)", s)
    if not m:
        m = re.search(r"(\d+(?:[.,]\d+)?)\s*m\b", s)
    if m:
        try:
            v = float(m.group(1).replace(",", "."))
            return v if 10 <= v <= 5000 else None
        except ValueError:
            return None
    return None


def parse_ambientes(s: str) -> Optional[int]:
    s = sin_acentos((s or "").lower())
    if "monoambiente" in s:
        return 1
    m = re.search(r"(\d+)\s*amb", s)
    return int(m.group(1)) if m else None


def parse_dormitorios(s: str) -> Optional[int]:
    s = sin_acentos((s or "").lower())
    m = re.search(r"(\d+)\s*(?:dorm|habitaci)", s)
    return int(m.group(1)) if m else None


# Señales de que el aviso lo publica una inmobiliaria aunque el filtro diga "dueño directo"
_INMOBILIARIA = [
    "inmobiliaria", "propiedades s.a", "bienes raices", "bienes raíces", "real estate",
    "honorarios", "comision", "comisión", "matricula", "matrícula", "cucicba", "cmcpsi",
    "corredor", "martillero", "col. n", "remax", "re/max", "century 21", "keller williams",
    "coldwell", "toribio achaval", "tizado", "lepore", "bresler", "mudafy",
]
_DUENO = ["dueño directo", "dueno directo", "dueño vende", "dueño alquila", "dueno alquila",
          "dueno vende", "sin comision", "sin comisión", "particular", "de dueño", "de dueno"]


def es_dueno_directo(*textos: str) -> bool:
    t = " ".join(x for x in textos if x).lower()
    if any(p in t for p in _DUENO):
        return True
    return not any(p in t for p in _INMOBILIARIA)


def json_ld(soup) -> Iterable[dict]:
    """Extrae los bloques JSON-LD (schema.org) que muchos portales embeben."""
    for tag in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(tag.string or "")
        except Exception:
            continue
        pila = data if isinstance(data, list) else [data]
        while pila:
            d = pila.pop()
            if isinstance(d, dict):
                yield d
                for k in ("@graph", "itemListElement"):
                    v = d.get(k)
                    if isinstance(v, list):
                        pila.extend(v)
                if isinstance(d.get("item"), dict):
                    pila.append(d["item"])
