import 'dart:io';

import 'package:fff_dart/fff_dart.dart';

void main() {
  final finder = FileFinder.open('/path/to/project');

  try {
    if (!finder.waitForScan(const Duration(seconds: 30))) {
      throw StateError('The initial file scan timed out');
    }

    final results = finder.searchFile('main.dart');
    for (final file in results.items) {
      stdout.writeln(file.relativePath);
    }
  } finally {
    finder.dispose();
  }
}
