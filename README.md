# Buscador de oportunidades inmobiliarias (dueño directo)

Todos los días a las **7:37 (hora argentina)** GitHub corre un buscador. Recorre **MercadoLibre Inmuebles, Argenprop y Zonaprop** en **CABA y GBA (Norte, Oeste y Sur)**, en **alquiler y venta** de departamentos, casas y PH. Se queda solo con los avisos de **dueño directo**, los puntúa como oportunidad y te manda un resumen al celular. La app Android muestra la lista completa con filtros.

Todo es gratis y no necesitás cargar tarjeta.

```
GitHub Actions (cron diario)          tu celular
┌──────────────────────────┐          ┌────────────────────────┐
│ scraper/main.py          │  commit  │ App "Oportunidades"    │
│  ├ MercadoLibre          │ ───────► │  lee data/             │
│  ├ Argenprop             │  data/   │  oportunidades.json    │
│  ├ Zonaprop              │          │  filtros · favoritos   │
│  └ puntaje + historial   │          └────────────────────────┘
│ ntfy.sh ─────────────────┼────────► notificación diaria
└──────────────────────────┘
```

## Puesta en marcha (una sola vez)

1. **Creá un repo público** en GitHub, por ejemplo `buscador-inmuebles`. Tiene que ser público por dos razones: así los minutos de Actions son ilimitados y la app puede leer los datos sin token.
2. **Subí este proyecto** desde la PC. La carpeta `.github` está oculta, así que conviene usar git en lugar de arrastrar archivos:
   ```
   cd C:\Users\Rodri\Desktop\buscador-inmuebles
   git init
   git add .
   git commit -m "Primera versión"
   git branch -M main
   git remote add origin https://github.com/TU_USUARIO/buscador-inmuebles.git
   git push -u origin main
   ```
3. **Dale permiso de escritura al bot.** Entrá a *Settings → Actions → General → Workflow permissions* y elegí **Read and write permissions**. Guardá.
4. **Configurá la notificación.** Entrá a *Settings → Secrets and variables → Actions → New repository secret*:
   - Name: `NTFY_TOPIC`
   - Value: un nombre difícil de adivinar, por ejemplo `oportunidades-rodri-7q2x9`. Los temas de ntfy son públicos, así que cualquiera que conozca el nombre puede leerlo.
5. **Hacé la primera búsqueda a mano.** En *Actions → Buscar oportunidades → Run workflow* lanzás la corrida. Tarda entre 5 y 15 minutos y al terminar aparece un commit en `data/`.
6. **Instalá la app.** El workflow *Compilar APK* corre solo cuando subís cambios en `app/`. Cuando termina, la APK queda en *Releases → Última APK*, y podés abrir esa página desde el celular para descargarla e instalarla. La firma es siempre la misma, así que las actualizaciones se instalan encima sin desinstalar.
7. **Instalá ntfy** desde Play Store (es gratis) y suscribite al mismo tema del paso 4.

La app ya trae cargado el repo, porque se inyecta al compilar. Si algún día lo renombrás, lo cambiás desde **Ajustes**.

## Cómo se decide qué es una "oportunidad"

El puntaje va de 0 a 100 y se ve en cada tarjeta:

| Factor | Efecto |
|---|---|
| Precio por m² comparado con la mediana del **mismo barrio** (o de la zona, si en el barrio hay pocos avisos), separando alquiler y venta y pesos y dólares | Es la base. Si está en la mediana vale 60, un 20% más barato vale 80 y un 40% más barato vale 100. |
| Sin superficie publicada | Se compara contra avisos con la misma cantidad de ambientes. |
| Precio menor al 35% de la mediana | Se limita a 25 y se marca *"sospechosamente bajo"*, porque suele ser un error de carga o una estafa. |
| Mismo inmueble publicado en varios portales | +6. Es la señal disponible de que el aviso es "visible" y real. |
| Visto por primera vez hoy | +5 |
| Tiene foto, m² y ambientes | +4 |
| Alquiler con expensas mayores al 45% del precio | −8 |

**Dueño directo:** se usa el filtro de cada portal (`/dueno-directo/`) y, encima de eso, se descartan los avisos que mencionan inmobiliaria, honorarios, comisión, matrícula, corredor o marcas conocidas como RE/MAX o Century 21.

**Sobre "las más visitadas":** ningún portal muestra las visitas en el listado. Por eso, como medida de popularidad, se usa que el aviso aparezca en las primeras páginas y que esté publicado en más de un portal.

## La app

- Pestañas **Alquiler**, **Venta** y **Favoritos**.
- Filtros guardados por separado para alquiler y para venta: zona, barrio o localidad, tipo, moneda, rango de precio, ambientes mínimos, m² mínimos, puntaje mínimo y "solo nuevos".
- Orden por mejor oportunidad, precio, precio por m² o recientes.
- Si deslizás un aviso a la izquierda lo ocultás para siempre. Se puede deshacer y se restaura desde Ajustes.
- La estrella guarda el aviso completo en el teléfono, así que no se pierde aunque salga del listado.
- Desde el detalle podés ver el motivo del puntaje, abrir el aviso en el portal o compartirlo por WhatsApp.
- Funciona sin conexión con los últimos datos descargados.

## Ajustes del buscador

Se editan en `scraper/config.json`, que podés modificar desde la web de GitHub con el lápiz:

- `operaciones`, `tipos` y `zonas`: definen qué se recorre. Cada zona tiene su "slug" en cada portal.
- `fuentes.*.paginas`: cuántas páginas leer por combinación.
- `puntaje_minimo_aviso`: a partir de qué puntaje un aviso entra en la notificación.
- `aviso_top`: cuántos avisos incluye la notificación.

El horario se cambia en `.github/workflows/buscar.yml`, en la línea `cron`, que está en UTC. Hay que sumarle 3 a la hora argentina.

## Limitaciones honestas

- **Zonaprop y Argenprop tienen protección anti-bots.** El buscador imita un navegador Chrome con `curl_cffi`, pero algunos días GitHub puede quedar bloqueado. Cuando pasa, esa fuente se saltea, las demás siguen y la app te avisa en la barra de estado qué portal no trajo datos.
- **Los portales cambian su HTML.** Si una fuente empieza a devolver 0 avisos varios días seguidos, hay que actualizar los selectores en `scraper/fuentes/<portal>.py`. `scraper/test_offline.py` ayuda a probar los cambios.
- **Los slugs de GBA en Argenprop** (`gba-norte`, etc.) son la mejor estimación posible. Si no devuelven nada, cambialos en `config.json` por los que aparezcan en la URL del sitio cuando filtrás esa zona.
- **Facebook Marketplace y los grupos de Facebook** no se pueden recorrer, porque exigen iniciar sesión.
- Leé los términos de uso de cada portal. Este proyecto hace pocas consultas por día, con pausas entre cada una, y es para uso personal.

## Probar en la PC

```
pip install -r scraper/requirements.txt
python scraper/test_offline.py      # pruebas sin internet
python scraper/main.py --rapido     # 1 página por fuente
```
