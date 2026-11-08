import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'modelo.dart';

/// Repo de GitHub de donde se leen los datos. El workflow lo inyecta al compilar
/// (--dart-define=REPO=usuario/repo) y se puede cambiar desde Ajustes.
const String repoCompilado = String.fromEnvironment('REPO', defaultValue: '');

class Servicio {
  Servicio._(this._prefs);
  final SharedPreferences _prefs;

  static Future<Servicio> iniciar() async => Servicio._(await SharedPreferences.getInstance());

  // ---------- Configuración ----------
  String get repo => _prefs.getString('repo') ?? repoCompilado;
  set repo(String v) => _prefs.setString('repo', v.trim());

  String get rama => _prefs.getString('rama') ?? 'main';
  set rama(String v) => _prefs.setString('rama', v.trim().isEmpty ? 'main' : v.trim());

  String get topicNtfy => _prefs.getString('ntfy') ?? '';
  set topicNtfy(String v) => _prefs.setString('ntfy', v.trim());

  Uri get urlDatos => Uri.parse(
      'https://raw.githubusercontent.com/$repo/$rama/data/oportunidades.json?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}');

  // ---------- Datos ----------
  Datos? datosEnCache() {
    final s = _prefs.getString('cache_datos');
    if (s == null) return null;
    try {
      return Datos.fromJsonString(s);
    } catch (_) {
      return null;
    }
  }

  Future<Datos> descargar() async {
    if (repo.isEmpty || !repo.contains('/')) {
      throw Exception('Configurá el repositorio en Ajustes (usuario/repo).');
    }
    final r = await http.get(urlDatos).timeout(const Duration(seconds: 25));
    if (r.statusCode == 404) {
      throw Exception('No encontré data/oportunidades.json en $repo. '
          '¿El repo es público y el buscador ya corrió al menos una vez?');
    }
    if (r.statusCode != 200) throw Exception('GitHub respondió ${r.statusCode}');
    final cuerpo = utf8.decode(r.bodyBytes);
    final datos = Datos.fromJsonString(cuerpo);
    await _prefs.setString('cache_datos', cuerpo);
    return datos;
  }

  // ---------- Favoritos y descartados ----------
  // Los favoritos se guardan completos para no perderlos cuando el aviso sale del listado.
  Map<String, Aviso> favoritos() {
    final s = _prefs.getString('favoritos_datos');
    if (s == null) return {};
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, Aviso.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<void> alternarFavorito(Aviso a) async {
    final s = _prefs.getString('favoritos_datos');
    final m = s == null ? <String, dynamic>{} : jsonDecode(s) as Map<String, dynamic>;
    if (m.containsKey(a.id)) {
      m.remove(a.id);
    } else {
      m[a.id] = a.raw;
    }
    await _prefs.setString('favoritos_datos', jsonEncode(m));
  }

  Set<String> get descartados => (_prefs.getStringList('descartados') ?? []).toSet();

  Future<void> descartar(String id) async {
    final d = descartados..add(id);
    await _prefs.setStringList('descartados', d.toList());
  }

  Future<void> restaurar(String id) async {
    final d = descartados..remove(id);
    await _prefs.setStringList('descartados', d.toList());
  }

  Future<void> limpiarDescartados() => _prefs.remove('descartados');

  // ---------- Filtros ----------
  Filtros filtros(String operacion) {
    final s = _prefs.getString('filtros_$operacion');
    if (s == null) return Filtros.porDefecto(operacion);
    try {
      return Filtros.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return Filtros.porDefecto(operacion);
    }
  }

  Future<void> guardarFiltros(String operacion, Filtros f) =>
      _prefs.setString('filtros_$operacion', jsonEncode(f.toJson()));
}
