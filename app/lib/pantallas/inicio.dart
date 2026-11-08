import 'package:flutter/material.dart';

import '../modelo.dart';
import '../servicio.dart';
import '../widgets/tarjeta_aviso.dart';
import 'ajustes.dart';
import 'detalle.dart';
import 'filtros.dart';

const zonasConocidas = ['CABA', 'GBA Norte', 'GBA Oeste', 'GBA Sur'];

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
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _actualizar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
  List<Aviso> get _todos => _datos?.avisos ?? const [];

  List<Aviso> _lista(String operacion) =>
      filtrarYOrdenar(_todos, operacion, _filtros[operacion]!, s.descartados);

  Future<void> _guardarFiltro(String op, Filtros f) async {
    setState(() => _filtros[op] = f);
    await s.guardarFiltros(op, f);
  }

  Future<void> _abrirFiltros() async {
    final op = _operacionActual;
    final zonas = {...zonasConocidas, for (final a in _todos) a.zona}.toList();
    final nuevo = await mostrarFiltros(
      context,
      filtros: _filtros[op]!.copia(),
      operacion: op,
      zonas: zonas,
      avisos: _todos,
      ocultos: s.descartados,
    );
    if (nuevo != null) await _guardarFiltro(op, nuevo);
  }

  void _abrirDetalle(Aviso a) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => PantallaDetalle(aviso: a, servicio: s, todos: _todos)));
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

  String _cuando(DateTime? t) {
    if (t == null) return 'todavía sin datos';
    final l = t.toLocal();
    final d = DateTime.now().difference(l);
    final hora = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    if (d.inHours < 24 && l.day == DateTime.now().day) return 'hoy $hora';
    if (d.inDays < 2) return 'ayer $hora';
    return 'hace ${d.inDays} días';
  }

  @override
  Widget build(BuildContext context) {
    final esFavoritos = _tabs.index == 2;
    final f = esFavoritos ? null : _filtros[_operacionActual]!;
    final favs = s.favoritos();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oportunidades', style: TextStyle(fontWeight: FontWeight.w800)),
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
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => PantallaAjustes(servicio: s, datos: _datos)));
              if (mounted) setState(() {});
              _actualizar();
            },
          ),
        ],
        bottom: TabBar(controller: _tabs, tabs: [
          Tab(child: _etiquetaTab('Alquiler', _lista('alquiler').length)),
          Tab(child: _etiquetaTab('Venta', _lista('venta').length)),
          Tab(child: _etiquetaTab('Favoritos', favs.length)),
        ]),
      ),
      body: Column(
        children: [
          if (_cargando) const LinearProgressIndicator(minHeight: 2),
          if (!esFavoritos) _chipsRapidos(f!),
          _barraEstado(),
          Expanded(
            child: TabBarView(controller: _tabs, children: [
              _listado(_lista('alquiler'), conDescartar: true),
              _listado(_lista('venta'), conDescartar: true),
              _listado(favs.values.toList()..sort((a, b) => b.puntaje.compareTo(a.puntaje)), conDescartar: false),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _etiquetaTab(String texto, int n) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(texto),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$n', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _chipsRapidos(Filtros f) {
    final op = _operacionActual;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        children: [
          ActionChip(
            avatar: const Icon(Icons.swap_vert, size: 18),
            label: Text(f.orden.texto),
            onPressed: () {
              final sig = Orden.values[(f.orden.index + 1) % Orden.values.length];
              _guardarFiltro(op, f.copia()..orden = sig);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Nuevos de hoy'),
            selected: f.soloNuevos,
            onSelected: (v) => _guardarFiltro(op, f.copia()..soloNuevos = v),
          ),
          for (final z in zonasConocidas) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: Text(z),
              selected: f.zonas.contains(z),
              onSelected: (v) {
                final c = f.copia();
                v ? c.zonas.add(z) : c.zonas.remove(z);
                _guardarFiltro(op, c);
              },
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(children: [
        Icon(Icons.update, size: 16, color: esq.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Actualizado ${_cuando(d.generado)} · $nuevos nuevos'
            '${caidas.isEmpty ? '' : ' · sin datos de ${caidas.join(', ')}'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: esq.outline),
          ),
        ),
      ]),
    );
  }

  Widget _listado(List<Aviso> avisos, {required bool conDescartar}) {
    final favs = s.favoritos().keys.toSet();
    final esq = Theme.of(context).colorScheme;
    if (avisos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _actualizar,
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: 32), children: [
          const SizedBox(height: 100),
          Icon(conDescartar ? Icons.search_off : Icons.star_border, size: 56, color: esq.outline),
          const SizedBox(height: 12),
          Text(
            conDescartar
                ? (_datos == null ? 'Bajando oportunidades…' : 'Nada con estos filtros')
                : 'Sin favoritos todavía',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            conDescartar
                ? 'Probá subir el precio máximo o sacar alguna zona.'
                : 'Tocá la estrella de un aviso para guardarlo acá. Queda guardado aunque el aviso salga del listado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: esq.outline),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _actualizar,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: avisos.length + (conDescartar ? 1 : 0),
        itemBuilder: (_, i) {
          if (conDescartar && i == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text('Deslizá un aviso a la izquierda para ocultarlo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: esq.outline)),
            );
          }
          final a = avisos[conDescartar ? i - 1 : i];
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
              color: esq.surfaceContainerHighest,
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
