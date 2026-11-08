import 'dart:io';

import 'package:buscador_inmuebles/modelo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee el JSON que genera el buscador y filtra', () {
    final datos = Datos.fromJsonString(File('test/muestra.json').readAsStringSync());
    expect(datos.avisos, isNotEmpty);
    expect(datos.fuentes.length, 3);
    final a = datos.avisos.first;
    expect(a.precio, isNotNull);
    expect(a.moneda, 'ARS');

    final f = Filtros.porDefecto('alquiler')..precioMax = 650000;
    final filtrados = datos.avisos.where(f.cumple).toList();
    expect(filtrados.every((x) => x.precio! <= 650000), isTrue);

    final barrio = Filtros(barrio: 'cabállito');
    expect(datos.avisos.where(barrio.cumple).every((x) => x.barrio == 'Caballito'), isTrue);

    final copia = Filtros.fromJson(f.toJson());
    expect(copia.precioMax, 650000);
    expect(formatoPrecio(1250000, 'ARS'), '\$ 1.250.000');
    expect(formatoPrecio(98500, 'USD'), 'US\$ 98.500');
  });
}
