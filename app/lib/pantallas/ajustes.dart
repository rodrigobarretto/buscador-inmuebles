import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../modelo.dart';
import '../servicio.dart';

class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key, required this.servicio, required this.datos});
  final Servicio servicio;
  final Datos? datos;

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  Servicio get s => widget.servicio;
  late final _repo = TextEditingController(text: s.repo);
  late final _rama = TextEditingController(text: s.rama);
  late final _ntfy = TextEditingController(text: s.topicNtfy);

  @override
  void dispose() {
    _repo.dispose();
    _rama.dispose();
    _ntfy.dispose();
    super.dispose();
  }

  Future<void> _abrirNtfy() async {
    final topic = _ntfy.text.trim();
    if (topic.isEmpty) return;
    final ok = await launchUrl(Uri.parse('https://ntfy.sh/$topic'), mode: LaunchMode.externalApplication);
    if (!ok) await Clipboard.setData(ClipboardData(text: topic));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fuentes = widget.datos?.fuentes ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Origen de los datos', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _repo,
            onChanged: (v) => s.repo = v,
            decoration: const InputDecoration(
              labelText: 'Repositorio de GitHub',
              hintText: 'usuario/buscador-inmuebles',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rama,
            onChanged: (v) => s.rama = v,
            decoration: const InputDecoration(labelText: 'Rama', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          Text('Notificación diaria', style: tema.textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            '1. Instalá la app gratuita "ntfy" desde Play Store.\n'
            '2. Suscribite al mismo tema que cargaste como secreto NTFY_TOPIC en GitHub.\n'
            '3. Cada mañana te llega el resumen; tocándolo abrís el mejor aviso.',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ntfy,
            onChanged: (v) => s.topicNtfy = v,
            decoration: InputDecoration(
              labelText: 'Tema de ntfy (solo de referencia)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.open_in_new), onPressed: _abrirNtfy),
            ),
          ),
          const SizedBox(height: 24),
          Text('Estado de las fuentes (última corrida)', style: tema.textTheme.titleMedium),
          if (fuentes.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Sin datos todavía')),
          for (final f in fuentes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(f.ok ? Icons.check_circle : Icons.error_outline,
                  color: f.ok ? Colors.green : tema.colorScheme.error),
              title: Text(f.nombre),
              subtitle: Text(f.ok ? '${f.cantidad} avisos de dueño directo' : f.error),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.visibility_outlined),
            label: Text('Volver a mostrar ocultados (${s.descartados.length})'),
            onPressed: () async {
              await s.limpiarDescartados();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
