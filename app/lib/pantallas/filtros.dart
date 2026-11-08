import 'package:flutter/material.dart';

import '../modelo.dart';

Future<Filtros?> mostrarFiltros(
  BuildContext context, {
  required Filtros filtros,
  required String operacion,
  required List<String> zonas,
  required List<Aviso> avisos,
  required Set<String> ocultos,
}) {
  return showModalBottomSheet<Filtros>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _HojaFiltros(
        filtros: filtros, operacion: operacion, zonas: zonas, avisos: avisos, ocultos: ocultos),
  );
}

class _HojaFiltros extends StatefulWidget {
  const _HojaFiltros({
    required this.filtros,
    required this.operacion,
    required this.zonas,
    required this.avisos,
    required this.ocultos,
  });
  final Filtros filtros;
  final String operacion;
  final List<String> zonas;
  final List<Aviso> avisos;
  final Set<String> ocultos;

  @override
  State<_HojaFiltros> createState() => _HojaFiltrosState();
}

class _HojaFiltrosState extends State<_HojaFiltros> {
  late Filtros f = widget.filtros;
  late final _min = TextEditingController(text: _txt(f.precioMin));
  late final _max = TextEditingController(text: _txt(f.precioMax));
  late final _m2 = TextEditingController(text: _txt(f.m2Min));
  late final _barrio = TextEditingController(text: f.barrio);

  static String _txt(double? v) => v == null ? '' : v.round().toString();
  static double? _num(String s) {
    final limpio = s.replaceAll(RegExp(r'[^0-9]'), '');
    return limpio.isEmpty ? null : double.parse(limpio);
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _m2.dispose();
    _barrio.dispose();
    super.dispose();
  }

  void _leerCampos() {
    f
      ..precioMin = _num(_min.text)
      ..precioMax = _num(_max.text)
      ..m2Min = _num(_m2.text)
      ..barrio = _barrio.text.trim();
  }

  int get _resultados {
    _leerCampos();
    return widget.avisos
        .where((a) => a.operacion == widget.operacion && !widget.ocultos.contains(a.id) && f.cumple(a))
        .length;
  }

  void _aplicar() {
    _leerCampos();
    Navigator.pop(context, f);
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );

  @override
  Widget build(BuildContext context) {
    final zonas = widget.zonas.isEmpty ? const ['CABA', 'GBA Norte', 'GBA Oeste', 'GBA Sur'] : widget.zonas;
    const tipos = {'departamentos': 'Departamento', 'casas': 'Casa', 'ph': 'PH'};
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Text('Filtros de ${widget.operacion}', style: Theme.of(context).textTheme.titleLarge),
                  _titulo('Ordenar por'),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final o in Orden.values)
                      ChoiceChip(
                        label: Text(o.texto),
                        selected: f.orden == o,
                        onSelected: (_) => setState(() => f.orden = o),
                      ),
                  ]),
                  _titulo('Zona'),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final z in zonas)
                      FilterChip(
                        label: Text(z),
                        selected: f.zonas.contains(z),
                        onSelected: (v) => setState(() => v ? f.zonas.add(z) : f.zonas.remove(z)),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _barrio,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Barrio o localidad (opcional)',
                      hintText: 'Ej: Caballito, Ramos Mejía',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  _titulo('Tipo'),
                  Wrap(spacing: 8, children: [
                    for (final e in tipos.entries)
                      FilterChip(
                        label: Text(e.value),
                        selected: f.tipos.contains(e.key),
                        onSelected: (v) => setState(() => v ? f.tipos.add(e.key) : f.tipos.remove(e.key)),
                      ),
                  ]),
                  _titulo('Precio'),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ARS', label: Text('Pesos')),
                      ButtonSegment(value: 'USD', label: Text('Dólares')),
                      ButtonSegment(value: '', label: Text('Ambas')),
                    ],
                    selected: {f.moneda},
                    onSelectionChanged: (s) => setState(() => f.moneda = s.first),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _min,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Desde', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _max,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Hasta', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ]),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ocultar avisos sin precio'),
                    value: f.ocultarSinPrecio,
                    onChanged: (v) => setState(() => f.ocultarSinPrecio = v),
                  ),
                  _titulo('Ambientes mínimos'),
                  Wrap(spacing: 8, children: [
                    for (final n in [null, 1, 2, 3, 4])
                      ChoiceChip(
                        label: Text(n == null ? 'Cualquiera' : '$n+'),
                        selected: f.ambientesMin == n,
                        onSelected: (_) => setState(() => f.ambientesMin = n),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _m2,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Superficie mínima (m²)', border: OutlineInputBorder(), isDense: true),
                  ),
                  _titulo('Puntaje mínimo de oportunidad: ${f.puntajeMin.round()}'),
                  Slider(
                    value: f.puntajeMin,
                    max: 90,
                    divisions: 9,
                    label: '${f.puntajeMin.round()}',
                    onChanged: (v) => setState(() => f.puntajeMin = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solo los nuevos de hoy'),
                    value: f.soloNuevos,
                    onChanged: (v) => setState(() => f.soloNuevos = v),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(children: [
                  TextButton(
                    onPressed: () {
                      final orden = f.orden;
                      setState(() {
                        f = Filtros.porDefecto(widget.operacion)..orden = orden;
                        _min.clear();
                        _max.clear();
                        _m2.clear();
                        _barrio.clear();
                      });
                    },
                    child: const Text('Limpiar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _aplicar,
                    icon: const Icon(Icons.check),
                    label: Builder(builder: (_) {
                      final n = _resultados;
                      return Text('Ver $n resultado${n == 1 ? '' : 's'}');
                    }),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
