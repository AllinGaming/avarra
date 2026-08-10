import 'package:avarra_core/avarra_core.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AvarraForgeApp());
}

class AvarraForgeApp extends StatelessWidget {
  const AvarraForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Avarra Forge',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFFD79A5B),
        ),
      ),
      home: const _FoundationScreen(),
    );
  }
}

class _FoundationScreen extends StatelessWidget {
  const _FoundationScreen();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(avarraProductName, style: textTheme.displaySmall),
              const SizedBox(height: 8),
              Text('Forge', style: textTheme.headlineMedium),
              const SizedBox(height: 20),
              const Text('Stage 0 · Repository Foundation'),
            ],
          ),
        ),
      ),
    );
  }
}
