import 'dart:io';

import 'package:avarra_server/avarra_server.dart';

void main() {
  final summary = runServerSimulation(logger: JsonLineAvarraLogger(stdout));
  stdout.writeln(serverStatusLine(summary));
}
