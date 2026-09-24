import 'package:fff_dart/fff_dart.dart';

import 'support.dart';

BenchmarkResult runFileSearchBenchmark(int iterations) {
  final root = createBenchmarkRoot('file-search');
  try {
    for (var index = 0; index < 1000; index++) {
      writeBenchmarkFile(root, 'module-$index.dart', 'entry $index\n');
    }

    final finder = openScannedFinder(root);
    try {
      const options = SearchOptions(pageSize: 20);
      return measureBenchmark(
        name: 'file search',
        workload: '1,000 files; query: module-500.dart',
        iterations: iterations,
        operation: () => finder.searchFile('module-500.dart', options: options),
        hasExpectedResults: (result) => result.items.isNotEmpty,
      );
    } finally {
      finder.dispose();
    }
  } finally {
    root.deleteSync(recursive: true);
  }
}
