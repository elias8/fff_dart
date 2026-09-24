import 'package:fff_dart/fff_dart.dart';

import 'support.dart';

BenchmarkResult runMixedSearchBenchmark(int iterations) {
  final root = createBenchmarkRoot('mixed-search');
  try {
    for (var index = 0; index < 1000; index++) {
      writeBenchmarkFile(root, 'module-$index/entry.dart', 'entry $index\n');
    }

    final finder = openScannedFinder(root);
    try {
      const options = SearchOptions(pageSize: 20);
      return measureBenchmark(
        name: 'mixed search',
        workload: '1,000 files + 1,000 directories; query: module-500',
        iterations: iterations,
        operation: () => finder.searchMixed('module-500', options: options),
        hasExpectedResults: (result) => result.items.isNotEmpty,
      );
    } finally {
      finder.dispose();
    }
  } finally {
    root.deleteSync(recursive: true);
  }
}
