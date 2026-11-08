import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../modelo.dart';
import '../servicio.dart';
import '../widgets/tarjeta_aviso.dart';

class PantallaDetalle extends StatefulWidget {
  const PantallaDetalle({super.key, required this.aviso, required this.servicio, required this.todos});
  final Aviso aviso;
  final Servicio servicio;
  final List<Aviso> todos;

  @override
  State<PantallaDetalle> createState() => _PantallaDetalleState();
}

class _PantallaDetalleState extends State<PantallaDetalle> {
  Aviso get a => widget.aviso;

  Future<void> _abrir() async {
    final ok = await launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pude abrir el aviso')));
    }
  }

  Future<void> _compartir() async {
    final texto = '${formatoPrecio(a.precio, a.moneda)} · ${a.tipoLegible}'
        '${a.ambientes != null ? ' ${a.ambientes} amb' : ''}'
        '${a.barrio.isNotEmpty ? ' en ${a.barrio}' : ''}\n${a.url}';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: texto));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado al portapapeles')));
      }
    }
  }

  Widget _dato(IconData i, String etiqueta, String valor) => ListTile(
        dense: true,
        leading: Icon(i),
        title: Text(etiqueta),
        trailing: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _comparacion() {
    final ref = referenciaBarrio(a, widget.todos);
    if (ref == null) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final tope = (ref.valor > ref.mediana ? ref.valor : ref.mediana) * 1.12;
    final mejor = ref.valor <= ref.mediana;
    Widget barra(String etiqueta, double v, Color color) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(etiqueta, style: tema.textTheme.bodyMedium)),
              Text('${formatoPrecio(v, a.moneda)}/m²', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: v / tope,
                minHeight: 10,
                color: color,
                backgroundColor: tema.colorScheme.surfaceContainerHighest,
              ),
            ),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Precio por m² frente al barrio', style: tema.textTheme.titleSmall),
        barra('Este aviso', ref.valor, mejor ? const Color(0xFF1E8E3E) : const Color(0xFFB4471F)),
        barra('Mediana en ${ref.donde} (${ref.cantidad} avisos)', ref.mediana, tema.colorScheme.outline),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fav = widget.servicio.favoritos().containsKey(a.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(a.fuente),
        actions: [
          IconButton(
            icon: Icon(fav ? Icons.star : Icons.star_border, color: fav ? Colors.amber : null),
            onPressed: () async {
              await widget.servicio.alternarFavorito(a);
              setState(() {});
            },
          ),
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _compartir),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (a.imagen.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(a.imagen, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              Expanded(
                child: Text(formatoPrecio(a.precio, a.moneda),
                    style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              InsigniaPuntaje(puntaje: a.puntaje, grande: true),
            ]),
          ),
          if (a.expensas != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('+ ${formatoPrecio(a.expensas, 'ARS')} de expensas'),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(a.titulo, style: tema.textTheme.titleMedium),
          ),
          if (a.motivos.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: tema.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Por qué aparece', style: tema.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    for (final m in a.motivos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $m'),
                      ),
                  ],
                ),
              ),
            ),
          _comparacion(),
          const SizedBox(height: 8),
          _dato(Icons.home_work_outlined, 'Tipo', a.tipoLegible),
          if (a.ambientes != null) _dato(Icons.meeting_room_outlined, 'Ambientes', '${a.ambientes}'),
          if (a.dormitorios != null) _dato(Icons.bed_outlined, 'Dormitorios', '${a.dormitorios}'),
          if (a.m2 != null) _dato(Icons.square_foot, 'Superficie', '${a.m2!.round()} m²'),
          if (a.precioM2 != null) _dato(Icons.calculate_outlined, 'Precio por m²', formatoPrecio(a.precioM2, a.moneda)),
          _dato(Icons.place_outlined, 'Zona', a.barrio.isNotEmpty ? '${a.barrio}, ${a.zona}' : a.zona),
          if (a.primeraVez.isNotEmpty) _dato(Icons.event_outlined, 'Visto por primera vez', a.primeraVez),
          if (a.direccion.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(a.direccion)),
          if (a.descripcion.isNotEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text(a.descripcion)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Antes de pagar nada: visitá la propiedad, pedí ver el título o el contrato y desconfiá '
              'de quien pida señas por adelantado sin mostrarla.',
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrir,
        icon: const Icon(Icons.open_in_new),
        label: Text('Ver en ${a.fuente}'),
      ),
    );
  }
}
