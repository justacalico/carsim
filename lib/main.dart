import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SimScreen(),
    );
  }
}

class SimScreen extends StatelessWidget {
  const SimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final body = wide ? const _WideLayout() : const _CompactLayout();
        return Scaffold(body: SafeArea(child: body));
      },
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Center(child: Text('sim view'))),
        SizedBox(width: 320, child: Center(child: Text('telemetry'))),
      ],
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(child: Center(child: Text('sim view'))),
        SizedBox(height: 160, child: Center(child: Text('controls'))),
      ],
    );
  }
}
