import 'package:flutter/material.dart';

import '../modelo.dart';

Color colorPuntaje(double p, ColorScheme esq) {
  if (p >= 80) return const Color(0xFF1E8E3E);
  if (p >= 65) return const Color(0xFF7CB342);
  if (p >= 50) return const Color(0xFFF9A825);
  return esq.outline;
}

class InsigniaPuntaje extends StatelessWidget {
  const InsigniaPuntaje({super.key, required this.puntaje, this.grande = false});
  final double puntaje;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final c = colorPuntaje(puntaje, Theme.of(context).colorScheme);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: grande ? 12 : 8, vertical: grande ? 6 : 3),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
      child: Text('${puntaje.round()}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: grande ? 18 : 13)),
    );
  }
}

class TarjetaAviso extends StatelessWidget {
  const TarjetaAviso({
    super.key,
    required this.aviso,
    required this.favorito,
    required this.onTap,
    required this.onFavorito,
  });

  final Aviso aviso;
  final bool favorito;
  final VoidCallback onTap;
  final VoidCallback onFavorito;

  @override
  Widget build(BuildContext context) {
    final a = aviso;
    final tema = Theme.of(context);
    final esq = tema.colorScheme;
    final datos = [
      if (a.ambientes != null) '${a.ambientes} amb',
      if (a.m2 != null) '${a.m2!.round()} m²',
      a.tipoLegible,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              height: 120,
              child: a.imagen.isEmpty
                  ? Container(color: esq.surfaceContainerHighest, child: const Icon(Icons.home_outlined, size: 40))
                  : Image.network(
                      a.imagen,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: esq.surfaceContainerHighest, child: const Icon(Icons.home_outlined)),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      InsigniaPuntaje(puntaje: a.puntaje),
                      const SizedBox(width: 8),
                      if (a.nuevo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: esq.tertiaryContainer, borderRadius: BorderRadius.circular(6)),
                          child: Text('NUEVO',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold, color: esq.onTertiaryContainer)),
                        ),
                      const Spacer(),
                      Text(a.fuente, style: tema.textTheme.labelSmall?.copyWith(color: esq.outline)),
                    ]),
                    const SizedBox(height: 6),
                    Text(formatoPrecio(a.precio, a.moneda),
                        style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (a.expensas != null)
                      Text('+ ${formatoPrecio(a.expensas, 'ARS')} expensas', style: tema.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(datos, style: tema.textTheme.bodySmall),
                    Text(
                      a.barrio.isNotEmpty ? '${a.barrio} · ${a.zona}' : a.zona,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: esq.outline),
                    ),
                    if (a.motivos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(a.motivos.first,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.bodySmall?.copyWith(color: esq.primary)),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: onFavorito,
              icon: Icon(favorito ? Icons.star : Icons.star_border, color: favorito ? Colors.amber : null),
            ),
          ],
        ),
      ),
    );
  }
}
