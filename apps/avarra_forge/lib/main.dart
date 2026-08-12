import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';

import 'src/forge_file_services.dart';
import 'src/forge_sample_world.dart';
import 'src/forge_workspace.dart';

void main() => runApp(const AvarraForgeApp());

class AvarraForgeApp extends StatelessWidget {
  const AvarraForgeApp({
    this.initialWorld,
    this.projectStorage,
    this.fileDialogs = const PlatformForgeFileDialogs(),
    this.enableRenderer = true,
    super.key,
  });

  final WorldDefinition? initialWorld;
  final ForgeProjectStorage? projectStorage;
  final ForgeFileDialogs fileDialogs;
  final bool enableRenderer;

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
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: ForgeWorkspaceScreen(
        initialWorld: initialWorld ?? createForgeStarterWorld(),
        projectStorage: projectStorage ?? ForgeProjectFileStorage(),
        fileDialogs: fileDialogs,
        enableRenderer: enableRenderer,
      ),
    );
  }
}
