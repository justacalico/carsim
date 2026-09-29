import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'ui/sim_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const CarSimApp(),
    ),
  );
}

class CarSimApp extends StatelessWidget {
  const CarSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'carsim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E1410),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5A1F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SimScreen(),
    );
  }
}
