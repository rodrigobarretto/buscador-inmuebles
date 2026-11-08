import 'dart:convert';

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
int? _i(dynamic v) => v == null ? null : (v as num).toInt();

class Aviso {
  final String id;
  final String fuente;
  final String url;
  final String titulo;
  final String operacion; // alquiler | venta
  final String tipo; // departamentos | casas | ph
  final String zona;
  final double? precio;
  final String? moneda; // ARS | USD
  final double? expensas;
  final double? m2;
  final int? ambientes;
  final int? dormitorios;
  final String barrio;
  final String direccion;
  final String imagen;
  final String descripcion;
  final bool duenoDirecto;
  final double puntaje;
  final List<String> motivos;
  final String primeraVez;
  final bool nuevo;
  final Map<String, dynamic> raw;

  Aviso.fromJson(Map<String, dynamic> j)
      : raw = j,
        id = j['id'] ?? '',
        fuente = j['fuente'] ?? '',
        url = j['url'] ?? '',
        titulo = j['titulo'] ?? '',
        operacion = j['operacion'] ?? '',
        tipo = j['tipo'] ?? '',
        zona = j['zona'] ?? '',
        precio = _d(j['precio']),
        moneda = j['moneda'],
        expensas = _d(j['expensas']),
        m2 = _d(j['m2']),
        ambientes = _i(j['ambientes']),
        dormitorios = _i(j['dormitorios']),
        barrio = j['barrio'] ?? '',
        direccion = j['direccion'] ?? '',
        imagen = j['imagen'] ?? '',
        descripcion = j['descripcion'] ?? '',
        duenoDirecto = j['dueno_directo'] ?? true,
        puntaje = _d(j['puntaje']) ?? 0,
        motivos = List<String>.from(j['motivos'] ?? const []),
        primeraVez = j['primera_vez'] ?? '',
        nuevo = j['nuevo'] ?? false;

  double? get precioM2 => (precio != null && m2 != null && m2! > 0) ? precio! / m2! : null;

  String get tipoLegible => switch (tipo) {
        'departamentos' => 'Departamento',
        'casas' => 'Casa',
        'ph' => 'PH',
        _ => tipo,
      };
}

class EstadoFuente {
  final String nombre;
  final bool ok;
  final int cantidad;
  final String error;
  EstadoFuente(this.nombre, Map<String, dynamic> j)
      : ok = j['ok'] ?? false,
        cantidad = _i(j['cantidad']) ?? 0,
        error = j['error'] ?? '';
}

class Datos {
  final DateTime? generado;
  final DateTime? ultimoIntento;
  final List<Aviso> avisos;
  final List<EstadoFuente> fuentes;

  Datos({this.generado, this.ultimoIntento, required this.avisos, required this.fuentes});

  factory Datos.fromJsonString(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    final est = (j['estado_fuentes'] as Map<String, dynamic>? ?? {});
    return Datos(
      generado: j['generado'] == null ? null : DateTime.tryParse(j['generado']),
      ultimoIntento: j['ultimo_intento'] == null ? null : DateTime.tryParse(j['ultimo_intento']),
      avisos: (j['avisos'] as List? ?? []).map((e) => Aviso.fromJson(e as Map<String, dynamic>)).toList(),
      fuentes: est.entries.map((e) => EstadoFuente(e.key, e.value as Map<String, dynamic>)).toList(),
    );
  }
}

enum Orden { puntaje, precio, precioM2, recientes }

extension OrdenTexto on Orden {
  String get texto => switch (this) {
        Orden.puntaje => 'Mejor oportunidad',
        Orden.precio => 'Precio más bajo',
        Orden.precioM2 => 'Precio por m² más bajo',
        Orden.recientes => 'Más recientes',
      };
}

/// Filtros que se guardan por separado para Alquiler y para Venta.
class Filtros {
  Set<String> zonas;
  Set<String> tipos;
  String barrio;
  String moneda; // '' = cualquiera
  double? precioMax;
  double? precioMin;
  int? ambientesMin;
  double? m2Min;
  double puntajeMin;
  bool soloNuevos;
  bool ocultarSinPrecio;
  Orden orden;

  Filtros({
    Set<String>? zonas,
    Set<String>? tipos,
    this.barrio = '',
    this.moneda = '',
    this.precioMax,
    this.precioMin,
    this.ambientesMin,
    this.m2Min,
    this.puntajeMin = 0,
    this.soloNuevos = false,
    this.ocultarSinPrecio = true,
    this.orden = Orden.puntaje,
  })  : zonas = zonas ?? {},
        tipos = tipos ?? {};

  factory Filtros.porDefecto(String operacion) =>
      Filtros(moneda: operacion == 'venta' ? 'USD' : 'ARS');

  Filtros copia() => Filtros.fromJson(toJson());

  int get activos {
    var n = 0;
    if (zonas.isNotEmpty) n++;
    if (tipos.isNotEmpty) n++;
    if (barrio.isNotEmpty) n++;
    if (precioMax != null || precioMin != null) n++;
    if (ambientesMin != null) n++;
    if (m2Min != null) n++;
    if (puntajeMin > 0) n++;
    if (soloNuevos) n++;
    return n;
  }

  bool cumple(Aviso a) {
    if (zonas.isNotEmpty && !zonas.contains(a.zona)) return false;
    if (tipos.isNotEmpty && !tipos.contains(a.tipo)) return false;
    if (barrio.isNotEmpty) {
      final b = _normal(barrio);
      if (!_normal('${a.barrio} ${a.direccion} ${a.titulo}').contains(b)) return false;
    }
    if (a.precio == null) {
      if (ocultarSinPrecio) return false;
    } else {
      if (moneda.isNotEmpty && a.moneda != moneda) return false;
      if (precioMax != null && a.precio! > precioMax!) return false;
      if (precioMin != null && a.precio! < precioMin!) return false;
    }
    if (ambientesMin != null && (a.ambientes == null || a.ambientes! < ambientesMin!)) return false;
    if (m2Min != null && (a.m2 == null || a.m2! < m2Min!)) return false;
    if (a.puntaje < puntajeMin) return false;
    if (soloNuevos && !a.nuevo) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'zonas': zonas.toList(),
        'tipos': tipos.toList(),
        'barrio': barrio,
        'moneda': moneda,
        'precioMax': precioMax,
        'precioMin': precioMin,
        'ambientesMin': ambientesMin,
        'm2Min': m2Min,
        'puntajeMin': puntajeMin,
        'soloNuevos': soloNuevos,
        'ocultarSinPrecio': ocultarSinPrecio,
        'orden': orden.index,
      };

  factory Filtros.fromJson(Map<String, dynamic> j) => Filtros(
        zonas: Set<String>.from(j['zonas'] ?? const []),
        tipos: Set<String>.from(j['tipos'] ?? const []),
        barrio: j['barrio'] ?? '',
        moneda: j['moneda'] ?? '',
        precioMax: _d(j['precioMax']),
        precioMin: _d(j['precioMin']),
        ambientesMin: _i(j['ambientesMin']),
        m2Min: _d(j['m2Min']),
        puntajeMin: _d(j['puntajeMin']) ?? 0,
        soloNuevos: j['soloNuevos'] ?? false,
        ocultarSinPrecio: j['ocultarSinPrecio'] ?? true,
        orden: Orden.values[(_i(j['orden']) ?? 0).clamp(0, Orden.values.length - 1)],
      );
}

String _normal(String s) {
  const de = 'áéíóúüñÁÉÍÓÚÜÑ';
  const a = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? a[i] : c);
  }
  return b.toString().toLowerCase();
}

String formatoPrecio(double? v, String? moneda) {
  if (v == null) return 'Consultar';
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${moneda == 'USD' ? 'US\$' : '\$'} $b';
}
