import 'package:flutter/material.dart';

import 'pantallas/inicio.dart';
import 'servicio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final servicio = await Servicio.iniciar();
  runApp(AppOportunidades(servicio: servicio));
}

class AppOportunidades extends StatelessWidget {
  const AppOportunidades({super.key, required this.servicio});
  final Servicio servicio;

  @override
  Widget build(BuildContext context) {
    const semilla = Color(0xFF1F7A5C);
    return MaterialApp(
      title: 'Oportunidades',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: semilla),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: semilla, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: PantallaInicio(servicio: servicio),
    );
  }
}
