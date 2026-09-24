import 'package:fff_dart/fff_dart.dart';

import 'support.dart';

BenchmarkResult runGlobBenchmark(int iterations) {
  final root = createBenchmarkRoot('glob');
  try {
    for (var index = 0; index < 1000; index++) {
      writeBenchmarkFile(root, 'module-$index/entry.dart', 'entry $index\n');
      writeBenchmarkFile(root, 'module-$index/README.md', 'readme $index\n');
    }

    final finder = openScannedFinder(root);
    try {
      const options = GlobOptions(pageSize: 20);
      return measureBenchmark(
        name: 'glob',
        workload: '2,000 files; pattern: **/*.dart',
        iterations: iterations,
        operation: () => finder.glob('**/*.dart', options: options),
        hasExpectedResults: (result) => result.items.isNotEmpty,
      );
    } finally {
      finder.dispose();
    }
  } finally {
    root.deleteSync(recursive: true);
  }
}
