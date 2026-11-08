import 'package:flutter/material.dart';

import '../modelo.dart';
import '../servicio.dart';
import '../widgets/tarjeta_aviso.dart';
import 'ajustes.dart';
import 'detalle.dart';
import 'filtros.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key, required this.servicio});
  final Servicio servicio;

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  Datos? _datos;
  bool _cargando = false;
  String? _error;
  late Map<String, Filtros> _filtros;

  Servicio get s => widget.servicio;

  @override
  void initState() {
    super.initState();
    _filtros = {'alquiler': s.filtros('alquiler'), 'venta': s.filtros('venta')};
    _datos = s.datosEnCache();
    _tabs.addListener(() => setState(() {}));
    _actualizar();
  }

  Future<void> _actualizar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await s.descargar();
      if (mounted) setState(() => _datos = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String get _operacionActual => _tabs.index == 0 ? 'alquiler' : 'venta';

  List<Aviso> _lista(String operacion) {
    final f = _filtros[operacion]!;
    final desc = s.descartados;
    final l = (_datos?.avisos ?? [])
        .where((a) => a.operacion == operacion && !desc.contains(a.id) && f.cumple(a))
        .toList();
    int cmpNull(double? x, double? y) {
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    }

    switch (f.orden) {
      case Orden.puntaje:
        l.sort((a, b) => b.puntaje.compareTo(a.puntaje));
      case Orden.precio:
        l.sort((a, b) => cmpNull(a.precio, b.precio));
      case Orden.precioM2:
        l.sort((a, b) => cmpNull(a.precioM2, b.precioM2));
      case Orden.recientes:
        l.sort((a, b) => b.primeraVez.compareTo(a.primeraVez) != 0
            ? b.primeraVez.compareTo(a.primeraVez)
            : b.puntaje.compareTo(a.puntaje));
    }
    return l;
  }

  Future<void> _abrirFiltros() async {
    final op = _operacionActual;
    final zonas = {for (final a in _datos?.avisos ?? <Aviso>[]) a.zona}.toList()..sort();
    final nuevo = await mostrarFiltros(context, _filtros[op]!.copia(), op, zonas);
    if (nuevo != null) {
      setState(() => _filtros[op] = nuevo);
      await s.guardarFiltros(op, nuevo);
    }
  }

  void _abrirDetalle(Aviso a) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaDetalle(aviso: a, servicio: s)));
    if (mounted) setState(() {});
  }

  Future<void> _descartar(Aviso a) async {
    await s.descartar(a.id);
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Aviso ocultado'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            await s.restaurar(a.id);
            if (mounted) setState(() {});
          },
        ),
      ));
  }

  String _hace(DateTime? t) {
    if (t == null) return 'todavía sin datos';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    return 'hace ${d.inDays} días';
  }

  @override
  Widget build(BuildContext context) {
    final esFavoritos = _tabs.index == 2;
    final f = esFavoritos ? null : _filtros[_operacionActual]!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oportunidades'),
        actions: [
          if (!esFavoritos)
            IconButton(
              tooltip: 'Filtros',
              onPressed: _abrirFiltros,
              icon: Badge(
                isLabelVisible: f!.activos > 0,
                label: Text('${f.activos}'),
                child: const Icon(Icons.tune),
              ),
            ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PantallaAjustes(servicio: s, datos: _datos)));
              if (mounted) setState(() {});
              _actualizar();
            },
          ),
        ],
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Alquiler'),
          Tab(text: 'Venta'),
          Tab(text: 'Favoritos'),
        ]),
      ),
      body: Column(
        children: [
          if (_cargando) const LinearProgressIndicator(minHeight: 2),
          _barraEstado(),
          Expanded(
            child: TabBarView(controller: _tabs, children: [
              _listado(_lista('alquiler'), conDescartar: true),
              _listado(_lista('venta'), conDescartar: true),
              _listado(s.favoritos().values.toList()..sort((a, b) => b.puntaje.compareTo(a.puntaje)),
                  conDescartar: false),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _barraEstado() {
    final esq = Theme.of(context).colorScheme;
    if (_error != null) {
      return Material(
        color: esq.errorContainer,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.wifi_off, color: esq.onErrorContainer),
          title: Text(_error!, style: TextStyle(color: esq.onErrorContainer)),
          trailing: TextButton(onPressed: _actualizar, child: const Text('Reintentar')),
        ),
      );
    }
    final d = _datos;
    if (d == null) return const SizedBox.shrink();
    final caidas = d.fuentes.where((x) => !x.ok).map((x) => x.nombre).toList();
    final nuevos = d.avisos.where((a) => a.nuevo).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        Icon(Icons.update, size: 16, color: esq.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Actualizado ${_hace(d.generado)} · $nuevos nuevos'
            '${caidas.isEmpty ? '' : ' · sin datos de ${caidas.join(', ')}'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: esq.outline),
          ),
        ),
      ]),
    );
  }

  Widget _listado(List<Aviso> avisos, {required bool conDescartar}) {
    final favs = s.favoritos().keys.toSet();
    if (avisos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _actualizar,
        child: ListView(children: [
          const SizedBox(height: 120),
          Icon(conDescartar ? Icons.search_off : Icons.star_border, size: 56,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Center(
            child: Text(conDescartar
                ? (_datos == null ? 'Bajando oportunidades…' : 'Nada con estos filtros')
                : 'Marcá avisos con la estrella para verlos acá'),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _actualizar,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: avisos.length,
        itemBuilder: (_, i) {
          final a = avisos[i];
          final tarjeta = TarjetaAviso(
            aviso: a,
            favorito: favs.contains(a.id),
            onTap: () => _abrirDetalle(a),
            onFavorito: () async {
              await s.alternarFavorito(a);
              setState(() {});
            },
          );
          if (!conDescartar) return tarjeta;
          return Dismissible(
            key: ValueKey(a.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Ocultar'),
                SizedBox(width: 8),
                Icon(Icons.visibility_off_outlined),
              ]),
            ),
            onDismissed: (_) => _descartar(a),
            child: tarjeta,
          );
        },
      ),
    );
  }
}
